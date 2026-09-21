// Remove BeamMP colour and formatting codes.
export function cleanName(value) {
  return typeof value === "string" ? value.replace(/\^[a-z0-9]/gi, "").trim() : "";
}

export function summarizeServers(list) {
  if (!Array.isArray(list)) throw new Error("Invalid BeamMP response");
  const servers = list.filter((server) => {
    const name = cleanName(server?.sname).replace(/^\[#\d+\]\s*/, "");
    return (/\bbeamng\s+france\b/i.test(name) && /\bslapush\b/i.test(name))
      || /^slapush['’]?\s*server\b/i.test(name);
  }).sort((a, b) => cleanName(a.sname).localeCompare(cleanName(b.sname), "fr", { numeric: true }));

  for (const server of servers) {
    if (!Number.isSafeInteger(server.players) || server.players < 0 || typeof server.map !== "string") {
      throw new Error("Invalid BeamNG France server data");
    }
  }
  const maps = [...new Set(servers.map((server) => {
    const name = server.map.match(/\/levels\/([^/]+)\//)?.[1] ?? server.map;
    return name.replaceAll("_", " ").replace(/\b\w/g, (letter) => letter.toUpperCase());
  }).filter(Boolean))];
  const franceServer = servers.find((server) => /\bbeamng\s+france\b/i.test(cleanName(server.sname)));
  const partnerServer = servers.find((server) => /^slapush['’]?\s*server\b/i.test(
    cleanName(server.sname).replace(/^\[#\d+\]\s*/, "")));
  return {
    name: franceServer && partnerServer ? "BeamNG France et Slapush'Server"
      : (franceServer || partnerServer) ? cleanName((franceServer || partnerServer).sname)
      .replace(/^\s*\[#\d+\]\s*/, "").split(/\s*\|\s*map\b/i)[0].trim()
      : "BeamNG France et Slapush'Server",
    players: servers.reduce((total, server) => total + server.players, 0),
    servers: servers.length,
    maps,
  };
}
