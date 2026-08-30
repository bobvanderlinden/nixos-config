import Quickshell.Hyprland
import QtQml

QtObject {
    function normalizedWindowAddress(windowAddress) {
        if (windowAddress === null || windowAddress === undefined || windowAddress === "")
            return "";
        const address = windowAddress.toString();
        return address.startsWith("0x") ? address.slice(2) : address;
    }

    function agentLabel(session) {
        return session?.label || session?.title || "";
    }

    function workspaceMostRecentAgent(workspaceId) {
        let mostRecentSession = null;
        for (const session of AgentState.sessions) {
            const windowAddress = normalizedWindowAddress(session.windowAddress);
            const toplevel = Hyprland.toplevels.values.find(item => item.address === windowAddress);
            if (toplevel?.workspace?.id !== workspaceId)
                continue;
            if (!mostRecentSession || session.updatedAt > mostRecentSession.updatedAt)
                mostRecentSession = session;
        }
        return mostRecentSession;
    }

    function items(query) {
        return Hyprland.workspaces.values
            .filter(workspace => workspace.id > 0)
            .sort((first, second) => first.id - second.id)
            .map(workspace => {
                const agent = workspaceMostRecentAgent(workspace.id);
                const agentText = agentLabel(agent);
                return {
                    label: agentText === "" ? workspace.id.toString() : `${workspace.id} ${agentText}`,
                    detail: "Workspace",
                    icon: "",
                    glyph: "#",
                    keywords: ["workspace", workspace.id.toString(), agentText],
                    activate: () => workspace.activate(),
                };
            });
    }
}
