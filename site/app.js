import { summarizeServers } from "./beammp.js";

const themeButton = document.querySelector(".theme-toggle");
if (themeButton) {
  themeButton.hidden = false;
  themeButton.addEventListener("click", () => {
    const light = document.documentElement.dataset.theme !== "light";
    document.documentElement.dataset.theme = light ? "light" : "dark";
    themeButton.setAttribute("aria-pressed", String(light));
    themeButton.setAttribute("aria-label", light ? "Activer le mode sombre" : "Activer le mode clair");
    themeButton.querySelector(".theme-icon").textContent = light ? "◐" : "☼";
    themeButton.querySelector(".theme-label").textContent = light ? "Sombre" : "Clair";
  });
}

const card = document.querySelector("#server-card");
if (card) {
  const status = document.querySelector("#server-status");
  const updated = document.querySelector("#server-updated");
  let lastUpdate = "";
  let pending = false;

  async function refresh() {
    if (pending || document.hidden) return;
    pending = true;
    card.setAttribute("aria-busy", "true");
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 12000);
    try {
      // Same-origin relay: BeamMP does not expose browser CORS headers.
      const response = await fetch("/api/beammp", { signal: controller.signal, cache: "no-store" });
      if (!response.ok) throw new Error("BeamMP: " + response.status);
      const stats = summarizeServers(await response.json());
      document.querySelector("#server-name").textContent = stats.name;
      document.querySelector("#player-count").textContent = stats.players;
      document.querySelector("#server-count").textContent = stats.servers;
      document.querySelector("#map-count").textContent = stats.maps.length;
      document.querySelector("#server-maps").replaceChildren(...stats.maps.map((map) => {
        const item = document.createElement("li");
        item.textContent = map;
        return item;
      }));
      status.textContent = stats.servers ? "EN LIGNE" : "AUCUN SERVEUR RÉPERTORIÉ";
      status.parentElement.classList.toggle("is-offline", !stats.servers);
      lastUpdate = new Date().toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" });
      updated.textContent = "Liste consultée à " + lastUpdate + " · actualisation chaque minute";
    } catch {
      // An API failure does not mean the game servers are offline.
      status.textContent = "STATISTIQUES INDISPONIBLES";
      status.parentElement.classList.add("is-offline");
      updated.textContent = lastUpdate
        ? "Dernières données reçues à " + lastUpdate + " · nouvelle tentative dans une minute"
        : "BeamMP ne répond pas pour le moment. Nouvelle tentative dans une minute.";
    } finally {
      clearTimeout(timeout);
      pending = false;
      card.setAttribute("aria-busy", "false");
    }
  }
  refresh();
  setInterval(refresh, 60000);
  document.addEventListener("visibilitychange", refresh);
}

const discordWidget = document.querySelector("#discord-widget");
if (discordWidget) {
  const count = document.querySelector("#discord-online-count");
  const members = document.querySelector("#discord-widget-members");
  const message = document.querySelector("#discord-widget-message");
  const memberRange = document.querySelector("#discord-member-range");
  let pending = false;
  let lastUpdate = "";

  async function refreshDiscord() {
    if (pending || document.hidden) return;
    pending = true;
    discordWidget.setAttribute("aria-busy", "true");
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 12000);
    try {
      const response = await fetch("/api/discord-widget", { signal: controller.signal, cache: "no-store" });
      if (!response.ok) throw new Error("Discord: " + response.status);
      const data = await response.json();
      if (data.id !== "828656939365957742" || !Number.isSafeInteger(data.presence_count)
          || data.presence_count < 0 || !Array.isArray(data.members)) {
        throw new Error("Invalid Discord widget response");
      }

      const invite = new URL(data.instant_invite);
      const inviteCode = invite.pathname.split("/").filter(Boolean).at(-1);
      if (!["discord.com", "discord.gg"].includes(invite.hostname)
          || !/^[A-Za-z0-9_-]{2,32}$/.test(inviteCode)) {
        throw new Error("Invalid Discord invite");
      }
      document.querySelectorAll("[data-discord-invite]").forEach((link) => {
        link.href = data.instant_invite;
      });

      const onlineMembers = data.members.filter((member) => member?.status === "online"
        && typeof member.username === "string" && member.username.trim()).slice(0, 4);
      members.replaceChildren(...onlineMembers.map((member) => {
        const item = document.createElement("li");
        item.textContent = member.username;
        item.title = member.username;
        return item;
      }));
      count.textContent = new Intl.NumberFormat("fr-FR").format(data.presence_count);
      discordWidget.classList.remove("is-unavailable");
      lastUpdate = new Date().toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" });
      message.textContent = "Aperçu du Discord · mis à jour à " + lastUpdate;
      if (!onlineMembers.length) {
        const item = document.createElement("li");
        item.textContent = "Aucun pseudo disponible pour le moment.";
        item.className = "discord-widget-empty";
        members.append(item);
      }

      try {
        // The widget has the current invitation; its public API has the approximate total.
        const inviteResponse = await fetch("/api/discord-invite/" + encodeURIComponent(inviteCode), {
          signal: controller.signal,
          cache: "no-store",
        });
        if (!inviteResponse.ok) throw new Error("Discord invite: " + inviteResponse.status);
        const inviteData = await inviteResponse.json();
        const memberCount = inviteData.approximate_member_count;
        if (inviteData.guild?.id !== "828656939365957742"
            || !Number.isSafeInteger(memberCount) || memberCount < 0) {
          throw new Error("Invalid Discord invite response");
        }
        const threshold = Math.floor(memberCount / 500) * 500;
        const formatted = new Intl.NumberFormat("fr-FR").format(threshold);
        memberRange.textContent = threshold > 0 && memberCount > threshold
          ? "Plus de " + formatted + " membres"
          : new Intl.NumberFormat("fr-FR").format(memberCount) + " membres";
      } catch {
        // Keep the last confirmed threshold, or the neutral label on first load.
      }
    } catch {
      discordWidget.classList.add("is-unavailable");
      if (!lastUpdate) {
        const item = document.createElement("li");
        item.textContent = "Aucun aperçu disponible pour le moment.";
        item.className = "discord-widget-empty";
        members.replaceChildren(item);
      }
      message.textContent = lastUpdate
        ? "Dernières données reçues à " + lastUpdate + " · nouvel essai dans cinq minutes."
        : "Le widget Discord ne répond pas pour le moment.";
    } finally {
      clearTimeout(timeout);
      pending = false;
      discordWidget.setAttribute("aria-busy", "false");
    }
  }

  refreshDiscord();
  setInterval(refreshDiscord, 300000);
  document.addEventListener("visibilitychange", refreshDiscord);
}
