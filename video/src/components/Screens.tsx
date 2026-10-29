import React from "react";
import { C } from "../theme";
import { BigButton, Row, Screen, TabBar, Title } from "./Phone";
import { Check } from "./Common";

export const LobbyScreen: React.FC<{ dots: number }> = ({ dots }) => (
  <Screen>
    <div style={{ marginTop: 150, textAlign: "center" }}>
      <div style={{ color: C.moon, fontSize: 18, fontWeight: 700, letterSpacing: 4 }}>MOONFALL</div>
      <div style={{ color: C.ink, fontSize: 46, fontWeight: 800, marginTop: 14 }}>Get Ready</div>
      <div style={{ color: C.dim, fontSize: 21, marginTop: 14 }}>Waiting for the OC to start{".".repeat(dots)}</div>
    </div>
  </Screen>
);

export const RoleScreen: React.FC<{ role: "villager" | "werewolf"; reveal: number }> = ({ role, reveal }) => {
  const col = role === "villager" ? C.villager : C.werewolf;
  return (
    <Screen>
      <Title>Your Role</Title>
      <div style={{ position: "relative", height: 420, borderRadius: 28, background: reveal > 0.5 ? col : C.panel2, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", color: "#fff" }}>
        {reveal <= 0.5 ? (
          <div style={{ fontSize: 26, fontWeight: 700, opacity: 0.9 }}>Tap to reveal</div>
        ) : (
          <>
            <div style={{ fontSize: 56, fontWeight: 800, letterSpacing: -1 }}>{role === "villager" ? "Villager" : "Werewolf"}</div>
            <div style={{ fontSize: 21, fontWeight: 500, marginTop: 14, textAlign: "center", padding: "0 28px", opacity: 0.92 }}>
              {role === "villager" ? "Finish your tasks. Find the werewolves." : "Stay hidden. Allies: 2 teams"}
            </div>
          </>
        )}
      </div>
    </Screen>
  );
};

const taskNames = ["Morse Code", "Painting", "Message", "Pattern", "Tower"];

export const TasksScreen: React.FC<{ done: number; notice?: number }> = ({ done, notice = 0 }) => (
  <Screen>
    <Title>Your Tasks</Title>
    <div style={{ color: C.dim, fontSize: 19, marginBottom: 12 }}>{done} of 5 stamps</div>
    {taskNames.map((n, i) => (
      <Row key={n}>
        {i < done ? <Check /> : <div style={{ width: 26, height: 26, borderRadius: 13, border: `3px solid ${C.dim}` }} />}
        <span style={{ opacity: i < done ? 0.6 : 1 }}>{n}</span>
      </Row>
    ))}
    <div style={{ position: "absolute", left: 22, right: 22, bottom: 92, opacity: notice, transform: `translateY(${(1 - notice) * 20}px)` }}>
      <Row color={C.warn} style={{ color: "#1B1100" }}>
        New notice: Meeting at Town Hall
      </Row>
    </div>
    <TabBar active={0} />
  </Screen>
);

export const ActionsScreen: React.FC<{ cooldown: number; killReady: boolean; sab?: boolean }> = ({ cooldown, killReady, sab = true }) => (
  <Screen>
    <Title>Actions</Title>
    <div style={{ color: C.dim, fontSize: 19, marginBottom: 16 }}>Villager devices nearby: 1</div>
    <BigButton color={C.werewolf} dim={!killReady}>
      {killReady ? "Kill" : `Kill  ·  ${cooldown}s`}
    </BigButton>
    {sab && <BigButton color={C.warn}>Sabotage</BigButton>}
    <TabBar active={2} />
  </Screen>
);

export const MeetingScreen: React.FC<{ secs: string; picked: number }> = ({ secs, picked }) => (
  <Screen>
    <Title>Meeting</Title>
    <div style={{ color: C.moon, fontSize: 68, fontWeight: 800, letterSpacing: -2, fontVariantNumeric: "tabular-nums" }}>{secs}</div>
    <div style={{ color: C.dim, fontSize: 19, margin: "6px 0 14px" }}>Vote for a team</div>
    {["Team 2", "Team 5", "Team 7"].map((t, i) => (
      <Row key={t} color={picked === i ? C.panel2 : C.panel} style={{ boxShadow: picked === i ? `inset 0 0 0 3px ${C.moon}` : undefined }}>
        {t}
      </Row>
    ))}
    <Row color="transparent" style={{ boxShadow: `inset 0 0 0 2px ${C.line}`, color: C.dim }}>
      Skip
    </Row>
    <TabBar active={1} />
  </Screen>
);

export const ResultScreen: React.FC<{ show: number }> = ({ show }) => (
  <Screen>
    <Title>Vote Result</Title>
    <div style={{ opacity: show, transform: `translateY(${(1 - show) * 20}px)` }}>
      <div style={{ borderRadius: 28, background: C.werewolf, padding: "40px 24px", color: "#fff", textAlign: "center" }}>
        <div style={{ fontSize: 20, fontWeight: 600, opacity: 0.9 }}>Team 5 was expelled</div>
        <div style={{ fontSize: 50, fontWeight: 800, marginTop: 10 }}>Werewolf</div>
      </div>
      <Row style={{ marginTop: 16 }}>1 werewolf team remains</Row>
    </div>
    <TabBar active={1} />
  </Screen>
);

export const SabotagePickScreen: React.FC<{ picked: number; confirmed: number }> = ({ picked, confirmed }) => (
  <Screen>
    <Title>Sabotage</Title>
    {["Reactor", "Oxygen"].map((n, i) => (
      <Row key={n} color={picked === i ? C.panel2 : C.panel} style={{ boxShadow: picked === i ? `inset 0 0 0 3px ${C.warn}` : undefined }}>
        {n}
      </Row>
    ))}
    <BigButton color={confirmed ? C.ok : C.warn} style={{ marginTop: 20 }}>
      {confirmed ? "Sent to OC" : "Confirm"}
    </BigButton>
    <TabBar active={2} />
  </Screen>
);
