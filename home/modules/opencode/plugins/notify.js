export const NotifyPlugin = async ({ $, client }) => {
  const windowAddress = process.env.HYPR_WINDOW_ADDRESS ?? null;

  async function getRootSessionInfo(sessionId) {
    const sessionInfo = (await client.session.get({ path: { id: sessionId } })).data;
    return sessionInfo?.parentID ? null : sessionInfo;
  }

  /**
   * Returns true if the OpenCode window is currently focused, meaning
   * the user is actively looking at it and does not need a notification.
   */
  async function isWindowFocused() {
    if (!windowAddress) return false;
    const activeAddress = (await $`hyprctl activewindow -j`.quiet().json()).address?.replace(/^0x/, "");
    return activeAddress === windowAddress;
  }

  /**
   * Derives a stable numeric notification ID from an arbitrary string so
   * that repeated events for the same subject replace the previous one.
   */
  function deriveNotifyId(text) {
    let notifyId = 0;
    for (let i = 0; i < text.length; i++) {
      notifyId = (notifyId * 31 + text.charCodeAt(i)) >>> 0;
    }
    return notifyId === 0 ? 42424242 : notifyId;
  }

  return {
    event: async ({ event }) => {
      switch (event.type) {
        case "session.error":
        case "session.idle": {
          const sessionId = event.properties.sessionID;
          if (!sessionId) throw new Error(`Expected sessionID in ${event.type} event`);

          // Only notify for top-level sessions.
          const sessionInfo = await getRootSessionInfo(sessionId);
          if (!sessionInfo) break;

          const title = sessionInfo?.title ?? "";

          // Skip notification if our window is currently focused.
          if (await isWindowFocused()) break;

          const notifyId = deriveNotifyId(sessionId);
          await $`coin`.quiet();
          await $`hypr-notify --app-name OpenCode --bell --replace-id ${String(notifyId)} 'OpenCode finished' ${title}`.quiet();
          break;
        }

        case "permission.asked": {
          const permission = event.properties;

          // Only notify for top-level sessions.
          const sessionInfo = await getRootSessionInfo(permission.sessionID);
          if (!sessionInfo) break;

          // Skip notification if our window is currently focused — the user
          // can already see the permission prompt in the TUI.
          if (await isWindowFocused()) break;

          const notifyId = deriveNotifyId(permission.id);
          const body = permission.title ?? "Permission requested";
          await $`hypr-notify --app-name OpenCode --replace-id ${String(notifyId)} 'OpenCode needs permission' ${body}`.quiet();
          break;
        }
      }
    },
  };
};
