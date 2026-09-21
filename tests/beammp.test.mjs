import assert from "node:assert/strict";
import test from "node:test";
import { summarizeServers } from "../site/beammp.js";

const server = (number, map, players = 0) => ({
  sname: "^l[#" + number + "] ^1BeamNG ^fFrance ^4[Powered by Slapush'Server] ^f| Map : ^f" + map,
  map: "/levels/" + map + "/info.json",
  players,
});

const partner = (number, map, players = 0) => ({
  ...server(number, map, players),
  sname: "^l[#" + number + "] ^4Slapush'Server [ALPHA] ^f| Map : ^f" + map,
});

test("includes BeamNG France and the partner's own servers without unrelated names", () => {
  const stats = summarizeServers([
    server(3, "jungle_rock_island", 2), server(1, "west_coast_usa", 5), server(2, "italy"),
    partner(4, "east_coast_usa", 3),
    { ...server(4, "utah", 99), sname: "BeamNG France — another community" },
    { ...server(4, "utah", 99), sname: "Slapush — other community" },
    null,
  ]);
  assert.equal(stats.name, "BeamNG France et Slapush'Server");
  assert.equal(stats.players, 10);
  assert.equal(stats.servers, 4);
  assert.deepEqual(stats.maps, ["West Coast Usa", "Italy", "Jungle Rock Island", "East Coast Usa"]);
});

test("partner servers remain visible when BeamNG France servers are absent", () => {
  const stats = summarizeServers([partner(1, "utah", 2)]);
  assert.equal(stats.name, "Slapush'Server [ALPHA]");
  assert.equal(stats.servers, 1);
  assert.equal(stats.players, 2);
});

test("zero players is a valid value and duplicate maps appear only once", () => {
  const stats = summarizeServers([server(1, "italy"), server(2, "italy")]);
  assert.equal(stats.players, 0);
  assert.equal(stats.servers, 2);
  assert.deepEqual(stats.maps, ["Italy"]);
});

test("an empty successful list is different from a malformed response", () => {
  assert.equal(summarizeServers([]).servers, 0);
  assert.throws(() => summarizeServers({ error: "unavailable" }));
  assert.throws(() => summarizeServers([server(1, "italy", "3")]));
  assert.throws(() => summarizeServers([server(1, "italy", -1)]));
});
