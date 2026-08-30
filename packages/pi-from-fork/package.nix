{ pi }:
pi.overrideAttrs (old: {
  # Backport bobvanderlinden/pi@819db428e (fix/codex-sse-fallback-only-1009)
  # to the npm release used by llm-agents.nix. The released tarball contains
  # compiled JavaScript, so patch it before Pi's Bun binary is assembled.
  preInstall = (old.preInstall or "") + ''
    substituteInPlace node_modules/@earendil-works/pi-ai/dist/api/openai-codex-responses.js \
      --replace-fail \
        'appendAssistantMessageDiagnostic(output, createAssistantMessageDiagnostic("provider_transport_failure", error, {
                            configuredTransport: transport,
                            fallbackTransport: websocketStarted ? undefined : "sse",' \
        'const fallbackToSse = !websocketStarted && isSseRequired(error);
                        appendAssistantMessageDiagnostic(output, createAssistantMessageDiagnostic("provider_transport_failure", error, {
                            configuredTransport: transport,
                            fallbackTransport: fallbackToSse ? "sse" : undefined,' \
      --replace-fail \
        'recordWebSocketFailure(cacheSessionId, error);
                        if (websocketStarted) {' \
        'recordWebSocketFailure(cacheSessionId, error, fallbackToSse);
                        if (!fallbackToSse) {' \
      --replace-fail \
        'function recordWebSocketFailure(sessionId, error) {
    if (!sessionId)
        return;
    websocketSseFallbackSessions.add(sessionId);' \
        'function recordWebSocketFailure(sessionId, error, activateSseFallback) {
    if (!sessionId)
        return;
    if (activateSseFallback) {
        websocketSseFallbackSessions.add(sessionId);
    }' \
      --replace-fail \
        'stats.websocketFallbackActive = true;
}
let _cachedWebsocket' \
        'stats.websocketFallbackActive = isWebSocketSseFallbackActive(sessionId);
}
function isSseRequired(error) {
    return error instanceof WebSocketCloseError && error.code === WEBSOCKET_MESSAGE_TOO_BIG_CLOSE_CODE;
}
let _cachedWebsocket'
  '';
})
