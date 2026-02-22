export const NotifyPlugin = async ({ $, client }) => {
  const windowAddress = process.env.HYPR_WINDOW_ADDRESS ?? null;

  return {
    event: async ({ event }) => {
      switch (event.type) {
        case "session.error":
        case "session.idle": {
          const sessionId = event.properties.sessionID;
          // Agent is now idle — fetch title.
          const sessionInfo = sessionId
            ? (await client.session.get({ path: { id: sessionId } })).data
            : null;
          const title = sessionInfo?.title ?? "";

          // Skip notification if our window is currently focused.
          const activeAddress = (await $`hyprctl activewindow -j`.quiet().json()).address;
          if (windowAddress && activeAddress === windowAddress) break;

          // Derive a stable numeric ID from the session ID so repeated
          // session.idle events replace the previous notification.
          let notifyId = 0;
          for (let i = 0; i < sessionId.length; i++) {
            notifyId = (notifyId * 31 + sessionId.charCodeAt(i)) >>> 0;
          }
          if (notifyId === 0) notifyId = 42424242;
          await $`coin`.quiet();
          await $`hypr-notify --app-name OpenCode --bell --replace-id ${String(notifyId)} 'OpenCode finished' ${title}`.quiet();
          break;
        }
      }
    },
  };
};
