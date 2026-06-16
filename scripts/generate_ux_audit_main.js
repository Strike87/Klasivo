/**
 * Klasivo UX Audit — MAIN ASSEMBLY.
 * Wires cover + TOC + 13 body sections into final .docx.
 *
 * Run: node /home/z/my-project/scripts/generate_ux_audit_main.js
 * Output: /home/z/my-project/download/Klasivo_UX_Audit.docx
 */

const U = require("./generate_ux_audit.js");
const {
  P, FONT, FONT_MONO,
  h1, h2, h3, p, code, bold, plain, bullet, spacer,
  buildCover,
  Document, Packer, Paragraph, TextRun, Header, Footer, PageNumber,
  NumberFormat, AlignmentType, HeadingLevel, SectionType, TableOfContents,
  PageBreak, LevelFormat,
} = U;

const fs = require("fs");
const path = require("path");

const { buildExecutiveSummary, buildCriticalIssues } = require("./audit_sections_1.js");
const { buildAuthScreenAudit, buildBrandingAudit } = require("./audit_sections_2.js");
const { buildTerminologyAudit, buildResponsiveAudit } = require("./audit_sections_3.js");
const { buildSettingsFeatureFlagsAudit, buildBottomNavAudit } = require("./audit_sections_4.js");
const { buildEmptyStatesAudit, buildAccessibilityAudit } = require("./audit_sections_5.js");
const { buildDesignSystemAudit, buildImplementationPlan, buildCodeChanges } = require("./audit_sections_6.js");

// ════════════════════════════════════════════════════════════════════
// TOC SECTION
// ════════════════════════════════════════════════════════════════════
function buildTocSection() {
  return [
    new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { before: 480, after: 360, line: 312 },
      children: [new TextRun({
        text: "Table of Contents",
        bold: true,
        size: 36,
        color: P.primary,
        font: FONT,
      })],
    }),
    new TableOfContents("Table of Contents", {
      hyperlink: true,
      headingStyleRange: "1-3",
    }),
    // Italic refresh hint — mandatory per skill rules
    new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { before: 200, after: 200, line: 312 },
      children: [new TextRun({
        text: "Right-click the table above and choose \u201cUpdate Field\u201d to refresh page numbers.",
        italics: true,
        size: 18,
        color: P.secondary,
        font: FONT,
      })],
    }),
    new Paragraph({ children: [new PageBreak()] }),
  ];
}

// ════════════════════════════════════════════════════════════════════
// FOOTERS
// ════════════════════════════════════════════════════════════════════
function bodyFooter() {
  return new Footer({
    children: [
      new Paragraph({
        alignment: AlignmentType.CENTER,
        spacing: { line: 240 },
        children: [
          new TextRun({
            children: [PageNumber.CURRENT],
            size: 18,
            color: P.secondary,
            font: FONT,
          }),
        ],
      }),
    ],
  });
}

function bodyHeader() {
  return new Header({
    children: [
      new Paragraph({
        alignment: AlignmentType.RIGHT,
        spacing: { line: 240 },
        children: [
          new TextRun({
            text: "Klasivo UX Audit  ·  v1.0",
            size: 18,
            color: P.secondary,
            font: FONT,
          }),
        ],
      }),
    ],
  });
}

// ════════════════════════════════════════════════════════════════════
// ASSEMBLE BODY CONTENT
// ════════════════════════════════════════════════════════════════════
function buildBody() {
  const body = [];
  body.push(...buildTocSection());
  body.push(...buildExecutiveSummary());
  body.push(...buildCriticalIssues());
  body.push(...buildAuthScreenAudit());
  body.push(...buildBrandingAudit());
  body.push(...buildTerminologyAudit());
  body.push(...buildResponsiveAudit());
  body.push(...buildSettingsFeatureFlagsAudit());
  body.push(...buildBottomNavAudit());
  body.push(...buildEmptyStatesAudit());
  body.push(...buildAccessibilityAudit());
  body.push(...buildDesignSystemAudit());
  body.push(...buildImplementationPlan());
  body.push(...buildCodeChanges());
  return body;
}

// ════════════════════════════════════════════════════════════════════
// DOCUMENT
// ════════════════════════════════════════════════════════════════════
const doc = new Document({
  creator: "Klasivo UX Audit",
  title: "Klasivo Mobile App — UX & Design System Audit",
  description: "Production-readiness audit covering 9 dimensions across 47 screens.",
  styles: {
    default: {
      document: {
        run: {
          font: FONT,
          size: 22,
          color: P.body,
        },
        paragraph: {
          spacing: { line: 312 },
        },
      },
      heading1: {
        run: {
          font: FONT,
          size: 32,
          bold: true,
          color: P.primary,
        },
        paragraph: {
          spacing: { before: 480, after: 200, line: 312 },
        },
      },
      heading2: {
        run: {
          font: FONT,
          size: 28,
          bold: true,
          color: P.primary,
        },
        paragraph: {
          spacing: { before: 360, after: 160, line: 312 },
        },
      },
      heading3: {
        run: {
          font: FONT,
          size: 24,
          bold: true,
          color: P.accent,
        },
        paragraph: {
          spacing: { before: 280, after: 120, line: 312 },
        },
      },
      heading4: {
        run: {
          font: FONT,
          size: 22,
          bold: true,
          color: P.body,
        },
        paragraph: {
          spacing: { before: 200, after: 100, line: 312 },
        },
      },
    },
  },
  numbering: {
    config: [
      {
        reference: "audit-bullets",
        levels: [
          {
            level: 0,
            format: LevelFormat.BULLET,
            text: "\u2022",
            alignment: AlignmentType.LEFT,
            style: { paragraph: { indent: { left: 720, hanging: 360 } } },
          },
          {
            level: 1,
            format: LevelFormat.BULLET,
            text: "\u25E6",
            alignment: AlignmentType.LEFT,
            style: { paragraph: { indent: { left: 1440, hanging: 360 } } },
          },
        ],
      },
    ],
  },
  sections: [
    // Section 1 — Cover (margin 0, no header/footer)
    {
      properties: {
        page: {
          size: { width: 11906, height: 16838 },
          margin: { top: 0, bottom: 0, left: 0, right: 0 },
        },
      },
      children: buildCover(),
    },
    // Section 2 — Body (standard margins, header + footer, page numbers from 1)
    {
      properties: {
        type: SectionType.NEXT_PAGE,
        page: {
          size: { width: 11906, height: 16838 },
          margin: { top: 1440, bottom: 1440, left: 1701, right: 1417 },
          pageNumbers: { start: 1, formatType: NumberFormat.DECIMAL },
        },
      },
      headers: { default: bodyHeader() },
      footers: { default: bodyFooter() },
      children: buildBody(),
    },
  ],
});

// ════════════════════════════════════════════════════════════════════
// PACK & WRITE
// ════════════════════════════════════════════════════════════════════
const outputPath = "/home/z/my-project/download/Klasivo_UX_Audit.docx";

Packer.toBuffer(doc).then((buffer) => {
  fs.writeFileSync(outputPath, buffer);
  const stats = fs.statSync(outputPath);
  console.log(`✓ Generated: ${outputPath}`);
  console.log(`  Size: ${(stats.size / 1024).toFixed(1)} KB`);
}).catch((err) => {
  console.error("✗ Generation failed:", err);
  process.exit(1);
});
