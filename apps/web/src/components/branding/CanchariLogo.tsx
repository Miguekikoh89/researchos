"use client";
import styles from "./CanchariLogo.module.css";

type CanchariLogoProps = {
  width?: number | string;
  showBackground?: boolean;
  className?: string;
};

export default function CanchariLogo({
  width = 1100,
  showBackground = true,
  className = "",
}: CanchariLogoProps) {
  return (
    <div
      className={`${styles.logoContainer} ${
        showBackground ? styles.withBackground : ""
      } ${className}`}
      style={{
        width: typeof width === "number" ? `${width}px` : width,
      }}
      aria-label="CanchariOS"
    >
      <svg
        className={styles.symbol}
        viewBox="0 0 320 360"
        role="img"
        aria-hidden="true"
      >
        <defs>
          <linearGradient
            id="canchari-main-gradient"
            x1="20"
            y1="20"
            x2="300"
            y2="330"
            gradientUnits="userSpaceOnUse"
          >
            <stop offset="0%" stopColor="#00F8DB" />
            <stop offset="28%" stopColor="#00B7FF" />
            <stop offset="58%" stopColor="#2459F6" />
            <stop offset="82%" stopColor="#7A3CFF" />
            <stop offset="100%" stopColor="#E348FF" />
          </linearGradient>
          <linearGradient
            id="canchari-bar-gradient"
            x1="0"
            y1="0"
            x2="1"
            y2="1"
          >
            <stop offset="0%" stopColor="#11F3D2" />
            <stop offset="45%" stopColor="#0987F8" />
            <stop offset="100%" stopColor="#7B3CFF" />
          </linearGradient>
          <linearGradient
            id="canchari-line-gradient"
            x1="80"
            y1="270"
            x2="240"
            y2="100"
            gradientUnits="userSpaceOnUse"
          >
            <stop offset="0%" stopColor="#0066D5" />
            <stop offset="35%" stopColor="#05E7D1" />
            <stop offset="70%" stopColor="#22C8FF" />
            <stop offset="100%" stopColor="#7651FF" />
          </linearGradient>
          <radialGradient id="node-fill" cx="35%" cy="25%" r="80%">
            <stop offset="0%" stopColor="#2FFFE8" />
            <stop offset="55%" stopColor="#169CEB" />
            <stop offset="100%" stopColor="#5135E8" />
          </radialGradient>
          <filter
            id="canchari-glow"
            x="-50%"
            y="-50%"
            width="200%"
            height="200%"
          >
            <feGaussianBlur stdDeviation="5" result="blur" />
            <feColorMatrix
              in="blur"
              type="matrix"
              values="
                0 0 0 0 0.05
                0 0 0 0 0.55
                0 0 0 0 1
                0 0 0 0.60 0
              "
              result="coloredBlur"
            />
            <feMerge>
              <feMergeNode in="coloredBlur" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
          <filter
            id="soft-shadow"
            x="-40%"
            y="-40%"
            width="180%"
            height="180%"
          >
            <feDropShadow
              dx="0"
              dy="5"
              stdDeviation="5"
              floodColor="#000000"
              floodOpacity="0.7"
            />
          </filter>
        </defs>
        {/* Hexágono exterior */}
        <path
          d="M160 25
             L286 105
             L286 255
             L160 335
             L34 255
             L34 105
             Z"
          fill="none"
          stroke="url(#canchari-main-gradient)"
          strokeWidth="19"
          strokeLinecap="round"
          strokeLinejoin="round"
          filter="url(#canchari-glow)"
        />
        {/* Barras estadísticas */}
        <g filter="url(#soft-shadow)">
          <rect
            x="82"
            y="246"
            width="27"
            height="62"
            rx="6"
            fill="url(#canchari-bar-gradient)"
          />
          <rect
            x="126"
            y="224"
            width="27"
            height="84"
            rx="6"
            fill="url(#canchari-bar-gradient)"
          />
          <rect
            x="170"
            y="192"
            width="27"
            height="116"
            rx="6"
            fill="url(#canchari-bar-gradient)"
          />
          <rect
            x="214"
            y="145"
            width="27"
            height="163"
            rx="6"
            fill="url(#canchari-bar-gradient)"
          />
        </g>
        {/* Línea ascendente */}
        <path
          d="M77 232
             C96 220, 110 209, 126 204
             C147 197, 151 178, 170 171
             C196 161, 211 136, 232 112"
          fill="none"
          stroke="url(#canchari-line-gradient)"
          strokeWidth="12"
          strokeLinecap="round"
          strokeLinejoin="round"
          filter="url(#canchari-glow)"
        />
        {/* Nodos de la gráfica */}
        <g filter="url(#soft-shadow)">
          <circle cx="105" cy="216" r="13" fill="url(#node-fill)" />
          <circle
            cx="169"
            cy="171"
            r="14"
            fill="#08122D"
            stroke="url(#canchari-main-gradient)"
            strokeWidth="8"
          />
          <circle
            cx="232"
            cy="112"
            r="15"
            fill="#08122D"
            stroke="url(#canchari-main-gradient)"
            strokeWidth="8"
          />
        </g>
        {/* Nodos exteriores */}
        <g filter="url(#canchari-glow)">
          <circle
            cx="160"
            cy="25"
            r="18"
            fill="#07112C"
            stroke="url(#canchari-main-gradient)"
            strokeWidth="9"
          />
          <circle
            cx="34"
            cy="180"
            r="18"
            fill="#07112C"
            stroke="url(#canchari-main-gradient)"
            strokeWidth="9"
          />
          <circle
            cx="286"
            cy="180"
            r="18"
            fill="#07112C"
            stroke="url(#canchari-main-gradient)"
            strokeWidth="9"
          />
          <circle
            cx="160"
            cy="335"
            r="18"
            fill="#07112C"
            stroke="url(#canchari-main-gradient)"
            strokeWidth="9"
          />
        </g>
      </svg>
      <div className={styles.wordmark}>
        <span className={styles.canchari}>Canchari</span>
        <span className={styles.os}>OS</span>
      </div>
    </div>
  );
}
