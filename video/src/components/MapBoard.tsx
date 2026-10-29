import React from "react";
import { C, FONT } from "../theme";

export const MAP_W = 1560;
export const MAP_H = 810;

export const POS = {
  townhall: { x: 377, y: 470 },
  photobooth: { x: 802, y: 365 },
  b1: { x: 966, y: 259 },
  b2: { x: 1042, y: 312 },
  b3: { x: 1132, y: 361 },
  b4: { x: 1387, y: 558 },
  b5: { x: 1300, y: 722 },
  b6: { x: 1185, y: 738 },
  b7: { x: 75, y: 258 },
  s1: { x: 1005, y: 738 },
  s2: { x: 75, y: 430 },
} as const;

export type Spot = keyof typeof POS;

const hexes = [
  [250, 270], [330, 260], [520, 270], [620, 270], [220, 360], [320, 360], [520, 360], [620, 360],
  [240, 560], [340, 570], [470, 560], [590, 560], [260, 650], [370, 660], [490, 650], [600, 650],
  [1090, 450], [1170, 440], [1290, 470], [1130, 530], [1370, 540], [1070, 600], [1200, 620], [1290, 610],
];

type Props = {
  scale?: number;
  reveal?: Partial<Record<Spot, number>>;
  pulse?: Partial<Record<Spot, number>>;
  children?: React.ReactNode;
  outlineOpacity?: number;
};

const labelOf: Record<Spot, string> = {
  townhall: "Town Hall",
  photobooth: "Photobooth",
  b1: "Booth 1",
  b2: "Booth 2",
  b3: "Booth 3",
  b4: "Booth 4",
  b5: "Booth 5",
  b6: "Booth 6",
  b7: "Booth 7",
  s1: "Sabotage 1",
  s2: "Sabotage 2",
};

export const MapBoard: React.FC<Props> = ({ scale = 1, reveal = {}, pulse = {}, children, outlineOpacity = 1 }) => {
  const spots = Object.keys(POS) as Spot[];
  return (
    <div style={{ position: "absolute", width: MAP_W, height: MAP_H, transform: `scale(${scale})`, transformOrigin: "top left", fontFamily: FONT }}>
      <svg width={MAP_W} height={MAP_H} style={{ position: "absolute", opacity: outlineOpacity }}>
        <path
          d="M20 205 L975 205 L1495 540 Q1505 610 1440 700 L1340 768 L20 768 Z"
          fill="rgba(255,255,255,0.04)"
          stroke="rgba(158,168,214,0.55)"
          strokeWidth="4"
          strokeLinejoin="round"
        />
        {hexes.map(([x, y], i) => (
          <circle key={i} cx={x} cy={y} r={26} fill="rgba(158,168,214,0.12)" />
        ))}
        <rect x={664} y={205} width={210} height={230} rx={8} fill="rgba(158,168,214,0.1)" />
      </svg>
      {spots.map((k) => {
        const r = reveal[k] ?? 1;
        const p = pulse[k] ?? 0;
        const isHall = k === "townhall";
        const isSab = k === "s1" || k === "s2";
        const isPhoto = k === "photobooth";
        const bg = isHall ? C.moon : isSab ? "#FF6A8A" : isPhoto ? "#7C8BFF" : "#E6EAFF";
        const ink = isHall || !isSab ? "#14183A" : "#2A0A14";
        const w = isHall ? 300 : isPhoto ? 230 : isSab ? 156 : 118;
        const h = isHall ? 130 : 52;
        return (
          <div
            key={k}
            style={{
              position: "absolute",
              left: POS[k].x - w / 2,
              top: POS[k].y - h / 2,
              width: w,
              height: h,
              borderRadius: isHall || isPhoto ? 999 : 30,
              background: bg,
              color: ink,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              fontSize: isHall ? 44 : 24,
              fontWeight: 800,
              opacity: r,
              transform: `scale(${0.6 + 0.4 * r + p * 0.12})`,
              boxShadow: p > 0 ? `0 0 0 ${8 + p * 14}px ${bg}55` : "none",
            }}
          >
            {labelOf[k]}
          </div>
        );
      })}
      {children}
    </div>
  );
};
