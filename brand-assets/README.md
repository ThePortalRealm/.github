# 🧩 The Portal Realm — Brand Assets

Central repository of official artwork, avatars, and branding for **The Portal Realm** organization.

---

## 🎯 Purpose
This directory provides a single source of truth for all visual assets used across The Portal Realm GitHub organization, social profiles, and partner pages.

All assets here are safe to use for:
- GitHub org avatars and repo banners
- Social media branding (Reddit, Discord, etc.)
- Wiki headers and promotional graphics
- External press or partner materials

---

## 🗂 Structure
```

brand-assets/
├── avatars/   → Org and team avatars
├── banners/   → Header images (desktop + mobile)
├── logo/      → Official logo marks (SVG + PNG)
├── palette.json → Color palette and theme values
└── README.md  → This file

````

---

## 🎨 Brand Palette
All official colors are defined in [`palette.json`](./palette.json).
Each entry contains HEX, RGB, and name identifiers for UI consistency across repos and sites.

Example:
```json
{
  "primary": "#33E1E8",
  "accent": "#8F6FFF",
  "dark": "#0B0F16",
  "light": "#E8EAF1"
}
````

---

## 🖼 Usage Guidelines

* **Do not edit** images directly — propose updates via PR.
* **Preferred formats:**

 * `.svg` for scalable use (recommended for headers and web)
 * `.png` for raster/social applications
* **Aspect ratios:**

 * Avatars: 1:1
 * Banners: 3:1 or Reddit-specific dimensions

---

## 🏗 Integration Example

Use a raw GitHub link for easy embedding:

```markdown
![Portal Realm Logo](https://raw.githubusercontent.com/ThePortalRealm/.github/main/brand-assets/logo/theportalrealm.png)
```

---

## 🧙 Credits

All artwork © The Portal Realm.
Design and brand direction by **Alpha** and the **Developer Guild**.

---

*Version 1.0 — maintained in `.github/brand-assets/`*
