import { closeSync } from "node:fs";
import { createRequire } from "node:module";

const requireFromOpencodeConfig = createRequire(
  `${process.env.HOME}/.config/opencode/package.json`,
);
const dbusNext = requireFromOpencodeConfig("dbus-next");

const LOGIND_SERVICE = "org.freedesktop.login1";
const LOGIND_PATH = "/org/freedesktop/login1";
const LOGIND_INTERFACE = "org.freedesktop.login1.Manager";
const INHIBIT_RECONCILE_INTERVAL_MS = 30_000;

/**
 * Holds a logind sleep/idle inhibitor lock while any top-level OpenCode session
 * in this instance is actively running.
 *
 * The lock is acquired through logind's D-Bus Inhibit() method, which returns
 * a Unix file descriptor. logind keeps the inhibitor for as long as that file
 * descriptor remains open, so we can release the lock by closing the descriptor
 * directly instead of keeping a helper process alive.
 *
 * A session is considered active when it is busy or retrying and not waiting
 * for a user question or permission reply.
 */
export const SystemdInhibitPlugin = async ({ client }) => {
  // Per root session state:
  // sessionId -> { isBusy: boolean, hasQuestion: boolean, pendingPermissions: Set<string> }
  const sessions = new Map();

  let inhibitFd = null;
  let inhibitDesired = false;
  let inhibitSync = Promise.resolve();

  let bus = null;
  let logindManager = null;
  let reconcilePromise = null;
  let shuttingDown = false;

  function isSessionActive({ isBusy, hasQuestion, pendingPermissions }) {
    return isBusy && !hasQuestion && pendingPermissions.size === 0;
  }

  function isBusyStatus(status) {
    return status?.type === "busy" || status?.type === "retry";
  }

  function updateDesiredInhibit() {
    inhibitDesired = [...sessions.values()].some(isSessionActive);
    void syncInhibitLock();
  }

  function setRootSession(sessionId, updates) {
    const current = sessions.get(sessionId) ?? {
      hasQuestion: false,
      isBusy: false,
      pendingPermissions: new Set(),
    };
    sessions.set(sessionId, { ...current, ...updates });
    updateDesiredInhibit();
  }

  function removeSession(sessionId) {
    if (!sessions.delete(sessionId)) return;
    updateDesiredInhibit();
  }

  function ensureBus() {
    if (bus !== null) return bus;

    bus = dbusNext.systemBus({ negotiateUnixFd: true });
    bus.on("error", () => {
      logindManager = null;
    });
    bus.on("end", () => {
      bus = null;
      logindManager = null;
    });

    return bus;
  }

  async function getLogindManager() {
    if (logindManager !== null) return logindManager;

    const proxy = await ensureBus().getProxyObject(LOGIND_SERVICE, LOGIND_PATH);
    logindManager = proxy.getInterface(LOGIND_INTERFACE);
    return logindManager;
  }

  async function acquireInhibitLock() {
    if (inhibitFd !== null) return;

    const manager = await getLogindManager();
    const nextFd = await manager.Inhibit(
      "idle:sleep",
      "opencode",
      "AI agent is running",
      "block",
    );

    if (!Number.isInteger(nextFd)) {
      throw new Error(`Expected logind Inhibit() to return an fd, got ${String(nextFd)}`);
    }

    if (!inhibitDesired || shuttingDown) {
      closeSync(nextFd);
      return;
    }

    inhibitFd = nextFd;
  }

  function releaseInhibitLock() {
    if (inhibitFd === null) return;

    const fd = inhibitFd;
    inhibitFd = null;

    try {
      closeSync(fd);
    } catch {
      // Ignore close races during shutdown.
    }
  }

  function syncInhibitLock() {
    inhibitSync = inhibitSync
      .catch(() => {})
      .then(async () => {
        while (!shuttingDown && inhibitDesired !== (inhibitFd !== null)) {
          if (inhibitDesired) {
            await acquireInhibitLock();
          } else {
            releaseInhibitLock();
          }
        }
      })
      .catch((error) => {
        console.error("SystemdInhibitPlugin failed to sync logind inhibitor", error);
      });

    return inhibitSync;
  }

  async function hydrateRootSession(sessionId, updates) {
    try {
      const { data: info } = await client.session.get({
        path: { id: sessionId },
        throwOnError: true,
      });
      if (info.parentID) {
        removeSession(sessionId);
        return;
      }
      setRootSession(sessionId, updates);
    } catch {
      // Ignore sessions that disappeared between the event and the lookup.
    }
  }

  function reconcileSessions() {
    if (reconcilePromise !== null) return reconcilePromise;

    reconcilePromise = Promise.all([
      client.session.list({
        query: { roots: true },
        throwOnError: true,
      }),
      client.session.status({
        throwOnError: true,
      }),
    ])
      .then(([listResponse, statusResponse]) => {
        const rootSessions = listResponse.data;
        const statuses = statusResponse.data;
        const rootSessionIds = new Set(rootSessions.map((session) => session.id));

        for (const sessionId of sessions.keys()) {
          if (!rootSessionIds.has(sessionId)) {
            sessions.delete(sessionId);
          }
        }

        for (const session of rootSessions) {
          const status = statuses[session.id];
          const busy = isBusyStatus(status);
          const current = sessions.get(session.id);

          sessions.set(session.id, {
            hasQuestion: busy ? current?.hasQuestion ?? false : false,
            isBusy: busy,
            pendingPermissions: busy ? current?.pendingPermissions ?? new Set() : new Set(),
          });
        }

        updateDesiredInhibit();
      })
      .catch((error) => {
        console.error("SystemdInhibitPlugin failed to reconcile sessions", error);
      })
      .finally(() => {
        reconcilePromise = null;
      });

    return reconcilePromise;
  }

  const reconcileTimer = setInterval(() => {
    void reconcileSessions();
  }, INHIBIT_RECONCILE_INTERVAL_MS);
  reconcileTimer.unref?.();
  void reconcileSessions();

  function shutdown() {
    if (shuttingDown) return;
    shuttingDown = true;
    clearInterval(reconcileTimer);
    releaseInhibitLock();
    bus?.disconnect();
    bus = null;
    logindManager = null;
  }

  process.on("exit", shutdown);
  process.on("SIGINT", () => {
    shutdown();
    process.exit(0);
  });
  process.on("SIGTERM", () => {
    shutdown();
    process.exit(0);
  });

  return {
    event: async ({ event }) => {
      switch (event.type) {
        case "session.created":
        case "session.updated": {
          const { info } = event.properties;
          if (info.parentID) {
            removeSession(info.id);
            break;
          }

          const current = sessions.get(info.id);
          setRootSession(info.id, {
            hasQuestion: current?.hasQuestion ?? false,
            isBusy: current?.isBusy ?? false,
            pendingPermissions: current?.pendingPermissions ?? new Set(),
          });
          break;
        }

        case "session.status": {
          const { sessionID, status } = event.properties;
          const busy = isBusyStatus(status);
          const current = sessions.get(sessionID);

          if (current) {
            setRootSession(sessionID, {
              hasQuestion: false,
              isBusy: busy,
            });
            break;
          }

          void hydrateRootSession(sessionID, {
            hasQuestion: false,
            isBusy: busy,
          });
          break;
        }

        case "message.part.updated": {
          const { part } = event.properties;
          if (part.type !== "tool" || part.tool !== "question") break;

          const current = sessions.get(part.sessionID);
          if (!current) break;

          const hasQuestion =
            part.state.status === "pending" || part.state.status === "running";
          setRootSession(part.sessionID, { hasQuestion });
          break;
        }

        case "permission.asked": {
          const { sessionID, id } = event.properties;
          const current = sessions.get(sessionID);

          if (current) {
            const pendingPermissions = new Set(current.pendingPermissions);
            pendingPermissions.add(id);
            setRootSession(sessionID, { pendingPermissions });
            break;
          }

          void hydrateRootSession(sessionID, {
            pendingPermissions: new Set([id]),
          });
          break;
        }

        case "permission.replied": {
          const { sessionID, requestID } = event.properties;
          const current = sessions.get(sessionID);
          if (!current) break;

          const pendingPermissions = new Set(current.pendingPermissions);
          pendingPermissions.delete(requestID);
          setRootSession(sessionID, { pendingPermissions });
          break;
        }

        case "session.error": {
          const { sessionID } = event.properties;
          const current = sessions.get(sessionID);
          if (!current) break;

          setRootSession(sessionID, {
            hasQuestion: false,
            isBusy: false,
            pendingPermissions: new Set(),
          });
          break;
        }

        case "session.idle": {
          const { sessionID } = event.properties;
          const current = sessions.get(sessionID);
          if (!current) break;

          setRootSession(sessionID, {
            hasQuestion: false,
            isBusy: false,
            pendingPermissions: new Set(),
          });
          break;
        }

        case "session.deleted": {
          removeSession(event.properties.info.id);
          break;
        }
      }
    },
  };
};
