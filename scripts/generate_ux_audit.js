/**
 * Klasivo Flutter App — Production-Readiness UX Audit
 * Generates a comprehensive .docx audit report with concrete code changes.
 *
 * Run: node /home/z/my-project/scripts/generate_ux_audit.js
 * Output: /home/z/my-project/download/Klasivo_UX_Audit.docx
 */

const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  PageBreak, Header, Footer, PageNumber, NumberFormat,
  AlignmentType, HeadingLevel, WidthType, BorderStyle, ShadingType,
  SectionType, TableOfContents, TableLayoutType, LevelFormat,
} = require("docx");
const fs = require("fs");
const path = require("path");

// ════════════════════════════════════════════════════════════════════
// PALETTE — Cool + Heavy + Active (Tech Indigo, matches Klasivo brand)
// ════════════════════════════════════════════════════════════════════
const P = {
  // Cover (R1 dark)
  bg:           "0F172A",  // slate-900
  titleColor:   "FFFFFF",
  subtitleColor:"CBD5E1",
  metaColor:    "94A3B8",
  accent:       "3B5BDB",  // Klasivo primary indigo
  footerColor:  "64748B",

  // Body
  primary:      "0F172A",  // H1/H2 text
  body:         "1E293B",  // body text
  secondary:    "475569",  // captions
  surface:      "F1F5F9",  // table alt rows / code bg
  surfaceAlt:   "F8FAFC",
  divider:      "E2E8F0",

  // Status badges
  critical:     "DC2626",
  high:         "EA580C",
  medium:       "CA8A04",
  low:          "16A34A",
  info:         "2563EB",

  // Code
  codeText:     "0F172A",
  codeComment:  "64748B",
};

// ════════════════════════════════════════════════════════════════════
// BORDERS
// ════════════════════════════════════════════════════════════════════
const NB = { style: BorderStyle.NONE, size: 0, color: "FFFFFF" };
const allNoBorders = {
  top: NB, bottom: NB, left: NB, right: NB,
  insideHorizontal: NB, insideVertical: NB,
};
const noCellBorders = { top: NB, bottom: NB, left: NB, right: NB };
const thinBorder = (color = P.divider, size = 1) => ({
  style: BorderStyle.SINGLE, size, color,
});
const tableBorders = {
  top:    thinBorder(P.secondary, 2),
  bottom: thinBorder(P.secondary, 2),
  left:   NB,
  right:  NB,
  insideHorizontal: thinBorder(P.divider, 1),
  insideVertical:   NB,
};

// ════════════════════════════════════════════════════════════════════
// HELPERS — Paragraph builders
// ════════════════════════════════════════════════════════════════════
const FONT = { ascii: "Calibri", eastAsia: "Microsoft YaHei" };
const FONT_MONO = { ascii: "DejaVu Sans Mono", eastAsia: "Sarasa Mono SC" };

function h1(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_1,
    spacing: { before: 480, after: 200, line: 312 },
    children: [new TextRun({ text, bold: true, size: 32, color: P.primary, font: FONT })],
  });
}

function h2(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_2,
    spacing: { before: 360, after: 160, line: 312 },
    children: [new TextRun({ text, bold: true, size: 28, color: P.primary, font: FONT })],
  });
}

function h3(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_3,
    spacing: { before: 280, after: 120, line: 312 },
    children: [new TextRun({ text, bold: true, size: 24, color: P.accent, font: FONT })],
  });
}

function h4(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_4,
    spacing: { before: 200, after: 100, line: 312 },
    children: [new TextRun({ text, bold: true, size: 22, color: P.body, font: FONT })],
  });
}

function p(text, opts = {}) {
  const runs = Array.isArray(text)
    ? text.map(t => typeof t === "string"
        ? new TextRun({ text: t, size: 22, color: P.body, font: FONT })
        : new TextRun({ ...t, size: t.size || 22, color: t.color || P.body, font: t.font || FONT }))
    : [new TextRun({ text, size: 22, color: P.body, font: FONT })];
  return new Paragraph({
    alignment: AlignmentType.LEFT,
    spacing: { before: 60, after: 120, line: 312 },
    ...opts,
    children: runs,
  });
}

// inline code (file path, identifier)
function code(text) {
  return { text, font: FONT_MONO, color: P.accent, size: 20 };
}

function bold(text) {
  return { text, bold: true, color: P.body, size: 22 };
}

function plain(text) {
  return { text, color: P.body, size: 22 };
}

// Severity badge as a colored bold run
function sev(label) {
  const colors = {
    "P0": P.critical, "P1": P.high, "P2": P.medium, "P3": P.low, "P4": P.info, "P5": P.secondary,
    "Critical": P.critical, "High": P.high, "Medium": P.medium, "Low": P.low,
  };
  return { text: `[${label}] `, bold: true, color: colors[label] || P.body, size: 22 };
}

function bullet(text, level = 0) {
  const runs = Array.isArray(text)
    ? text.map(t => typeof t === "string"
        ? new TextRun({ text: t, size: 22, color: P.body, font: FONT })
        : new TextRun({ ...t, size: t.size || 22, color: t.color || P.body, font: t.font || FONT }))
    : [new TextRun({ text, size: 22, color: P.body, font: FONT })];
  return new Paragraph({
    numbering: { reference: "audit-bullets", level },
    spacing: { before: 40, after: 80, line: 312 },
    children: runs,
  });
}

// Code block — single cell table with mono font + surface bg
function codeBlock(codeText, language = "dart") {
  const lines = codeText.split("\n");
  const codeParas = lines.map(line =>
    new Paragraph({
      spacing: { before: 0, after: 0, line: 280 },
      children: [new TextRun({
        text: line || " ",
        font: FONT_MONO,
        size: 18,
        color: P.codeText,
      })],
    })
  );
  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    borders: {
      top:    thinBorder(P.divider, 1),
      bottom: thinBorder(P.divider, 1),
      left:   thinBorder(P.accent, 8),
      right:  thinBorder(P.divider, 1),
      insideHorizontal: NB,
      insideVertical:   NB,
    },
    rows: [new TableRow({
      cantSplit: false,
      children: [new TableCell({
        shading: { type: ShadingType.CLEAR, fill: P.surface },
        margins: { top: 160, bottom: 160, left: 200, right: 160 },
        width: { size: 100, type: WidthType.PERCENTAGE },
        children: codeParas,
      })],
    })],
  });
}

// Callout / note box — colored left border + tinted bg
function callout(label, text, color = P.info) {
  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    borders: {
      top: NB, bottom: NB, right: NB,
      left:   { style: BorderStyle.SINGLE, size: 16, color },
      insideHorizontal: NB, insideVertical: NB,
    },
    rows: [new TableRow({
      cantSplit: true,
      children: [new TableCell({
        shading: { type: ShadingType.CLEAR, fill: P.surfaceAlt },
        margins: { top: 120, bottom: 120, left: 200, right: 160 },
        width: { size: 100, type: WidthType.PERCENTAGE },
        children: [
          new Paragraph({
            spacing: { after: 60, line: 312 },
            children: [
              new TextRun({ text: `${label}  `, bold: true, color, size: 20, font: FONT }),
            ],
          }),
          new Paragraph({
            spacing: { line: 312 },
            children: [
              new TextRun({ text, size: 20, color: P.body, font: FONT }),
            ],
          }),
        ],
      })],
    })],
  });
}

// Generic table builder — first row is header
function dataTable(headers, rows, colWidths = null) {
  const width = (i) => colWidths ? colWidths[i] : Math.floor(100 / headers.length);
  const headerRow = new TableRow({
    tableHeader: true,
    cantSplit: true,
    children: headers.map((text, i) => new TableCell({
      shading: { type: ShadingType.CLEAR, fill: P.primary },
      margins: { top: 80, bottom: 80, left: 120, right: 120 },
      width: { size: width(i), type: WidthType.PERCENTAGE },
      children: [new Paragraph({
        spacing: { line: 280 },
        children: [new TextRun({ text, bold: true, color: "FFFFFF", size: 20, font: FONT })],
      })],
    })),
  });
  const dataRows = rows.map((row, ri) => new TableRow({
    cantSplit: true,
    children: row.map((cell, ci) => {
      const isObj = typeof cell === "object" && cell !== null && !Array.isArray(cell);
      const text = isObj ? cell.text : String(cell);
      const cellColor = isObj && cell.color ? cell.color : P.body;
      const cellBold = isObj && cell.bold ? true : false;
      const cellFont = (isObj && cell.mono) ? FONT_MONO : FONT;
      const cellSize = (isObj && cell.size) ? cell.size : 20;
      return new TableCell({
        shading: { type: ShadingType.CLEAR, fill: ri % 2 === 0 ? "FFFFFF" : P.surfaceAlt },
        margins: { top: 80, bottom: 80, left: 120, right: 120 },
        width: { size: width(ci), type: WidthType.PERCENTAGE },
        children: [new Paragraph({
          spacing: { line: 280 },
          children: [new TextRun({ text, color: cellColor, bold: cellBold, font: cellFont, size: cellSize })],
        })],
      });
    }),
  }));
  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    borders: tableBorders,
    rows: [headerRow, ...dataRows],
  });
}

// Spacer paragraph
function spacer(size = 120) {
  return new Paragraph({ spacing: { before: 0, after: size }, children: [] });
}

// ════════════════════════════════════════════════════════════════════
// COVER PAGE — Recipe R1 (Pure Paragraph Left, dark tech)
// ════════════════════════════════════════════════════════════════════
function buildCover() {
  const padL = 1200, padR = 800;
  const accentLeft = { style: BorderStyle.SINGLE, size: 8, color: P.accent, space: 12 };
  const children = [];

  // Top whitespace
  children.push(new Paragraph({ spacing: { before: 2400 }, children: [] }));

  // English label with accent bottom border
  children.push(new Paragraph({
    indent: { left: padL, right: padR },
    spacing: { after: 500 },
    border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: P.accent, space: 8 } },
    children: [new TextRun({
      text: "P R O D U C T I O N   R E A D I N E S S   A U D I T",
      size: 18, color: P.accent, font: FONT, characterSpacing: 40,
    })],
  }));

  // Title — line 1
  children.push(new Paragraph({
    indent: { left: padL },
    spacing: { after: 100, line: 920, lineRule: "atLeast" },
    children: [new TextRun({
      text: "Klasivo Mobile App",
      size: 80, bold: true, color: P.titleColor, font: FONT,
    })],
  }));

  // Title — line 2
  children.push(new Paragraph({
    indent: { left: padL },
    spacing: { after: 400, line: 920, lineRule: "atLeast" },
    children: [new TextRun({
      text: "UX & Design System Audit",
      size: 80, bold: true, color: P.titleColor, font: FONT,
    })],
  }));

  // Subtitle
  children.push(new Paragraph({
    indent: { left: padL },
    spacing: { after: 1000 },
    children: [new TextRun({
      text: "Onboarding, authentication, branding, navigation, and mobile UX review",
      size: 26, color: P.subtitleColor, font: FONT,
    })],
  }));

  // Meta lines
  const metaLines = [
    "Document type:  Production-readiness audit report",
    "App version:    Klasivo v2.0.0+7 (Flutter / Firebase)",
    "Audit date:     June 16, 2026",
    "Auditor:        Senior Flutter architect & product designer",
    "Scope:          9 audit dimensions × 47 screens audited",
  ];
  for (const line of metaLines) {
    children.push(new Paragraph({
      indent: { left: padL + 200 },
      spacing: { after: 80 },
      border: { left: accentLeft },
      children: [new TextRun({
        text: line, size: 22, color: P.metaColor, font: FONT,
      })],
    }));
  }

  // Bottom whitespace
  children.push(new Paragraph({ spacing: { before: 3200 }, children: [] }));

  // Footer with top accent
  children.push(new Paragraph({
    indent: { left: padL, right: padR },
    border: { top: { style: BorderStyle.SINGLE, size: 2, color: P.accent, space: 8 } },
    spacing: { before: 200 },
    children: [
      new TextRun({ text: "KLASIVO  ·  CONFIDENTIAL", size: 16, color: P.footerColor, font: FONT, characterSpacing: 30 }),
      new TextRun({ text: "                                                        " }),
      new TextRun({ text: "Audit Report v1.0", size: 16, color: P.footerColor, font: FONT }),
    ],
  }));

  return [new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    layout: TableLayoutType.FIXED,
    borders: allNoBorders,
    rows: [new TableRow({
      height: { value: 16838, rule: "exact" },
      children: [new TableCell({
        shading: { type: ShadingType.CLEAR, fill: P.bg },
        borders: noCellBorders,
        children,
      })],
    })],
  })];
}

module.exports = {
  P, FONT, FONT_MONO, NB, allNoBorders, noCellBorders, thinBorder, tableBorders,
  h1, h2, h3, h4, p, code, bold, plain, sev, bullet,
  codeBlock, callout, dataTable, spacer, buildCover,
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  PageBreak, Header, Footer, PageNumber, NumberFormat,
  AlignmentType, HeadingLevel, WidthType, BorderStyle, ShadingType,
  SectionType, TableOfContents, TableLayoutType, LevelFormat,
};
