# Design System Document: The Sacred Pause

## 1. Overview & Creative North Star
The Creative North Star for this design system is **"The Sacred Pause."** 

In an era of digital noise, this system is designed to act as a sanctuary. It moves beyond the "utility" of a standard planning app to create an editorial, meditative experience. We achieve this by rejecting the rigid, boxy constraints of traditional mobile UI in favor of **Organic Minimalism**. 

The design breaks the "template" look through intentional asymmetry, expansive negative space (breathing room), and a hierarchy that favors serenity over urgency. By utilizing high-contrast typography scales and layered, translucent surfaces, we create a rhythmic flow that mirrors the intentionality of daily prayer and reflection.

---

## 2. Colors & Tonal Architecture
The palette is rooted in nature—specifically the intersection of desert sands (`#fbf9f4`) and olive-toned botanicals (`#546356`).

### The "No-Line" Rule
**Borders are prohibited for sectioning.** To define boundaries, designers must use background color shifts. A section should be distinguished by moving from `surface` (`#fbf9f4`) to `surface-container-low` (`#f5f4ed`). This creates a soft, sophisticated transition that feels architectural rather than "coded."

### Surface Hierarchy & Nesting
Treat the UI as a series of physical layers—like stacked sheets of fine vellum.
- **Base:** `surface` (`#fbf9f4`) for the main app background.
- **Sectioning:** Use `surface-container-low` (`#f5f4ed`) for large structural blocks.
- **Content Vessels:** Use `surface-container-lowest` (`#ffffff`) for cards or interactive elements to make them "pop" forward naturally.

### The "Glass & Gradient" Rule
To elevate the experience from flat to premium, use **Glassmorphism** for floating elements (e.g., navigation bars, modal overlays). Apply `surface-container-lowest` at 70% opacity with a `20px` backdrop blur. 
- **Signature Texture:** For primary Call-to-Actions (CTAs), use a subtle linear gradient from `primary` (`#546356`) to `primary-dim` (`#48574a`) at a 135-degree angle. This adds a "soulful" depth that a flat color cannot provide.

---

## 3. Typography: Editorial Authority
We use **Manrope** as our sole typeface. Its modern, geometric construction provides the clarity needed for planning, while its open apertures feel welcoming.

*   **Display (lg/md):** Used for moments of high reflection or "State of the Day" headers. High scale creates a luxurious, editorial feel.
*   **Headline (sm/md):** Used for primary section titles. These should have generous top-padding to allow the content to breathe.
*   **Body (lg/md):** The workhorse for task descriptions and journaling. Maintain a line-height of at least 1.5x for maximum legibility.
*   **Label (sm):** Used for metadata (e.g., prayer times, dates). Always use `on-surface-variant` (`#5e6059`) to keep the visual weight light.

---

## 4. Elevation & Depth: Tonal Layering
Traditional shadows are often "dirty." In this system, depth is achieved through light and layering.

*   **The Layering Principle:** Achieve lift by stacking tiers. A `surface-container-lowest` card sitting on a `surface-container-high` background creates a natural focal point without needing a single pixel of shadow.
*   **Ambient Shadows:** When a shadow is required for a floating action button or a high-priority modal, use a tinted shadow.
    *   *Formula:* `Color: #31332e (on-surface) | Opacity: 4-6% | Blur: 30px | Y-Offset: 10px`.
*   **The "Ghost Border" Fallback:** If a border is required for accessibility in input fields, use `outline-variant` (`#b2b2ab`) at **15% opacity**. Never use 100% opaque lines.
*   **Glassmorphism Depth:** For floating "Glass" cards, use a 0.5px inner-stroke of `surface-container-lowest` at 50% opacity to simulate the edge of a glass pane catching the light.

---

## 5. Components

### Buttons
- **Primary:** Filled with the Sage gradient. Radius: `full`. Text: `on-primary` (`#edfded`).
- **Secondary (Glass):** `surface-container-lowest` at 40% opacity + backdrop blur. No border.
- **Tertiary:** Text-only using `primary` (`#546356`) with a `label-md` weight.

### Cards & Lists
- **The Divider Ban:** Never use horizontal lines to separate list items. Use 24px of vertical white space or alternate subtle background tints (`surface` vs `surface-container-low`).
- **Cards:** Use `xl` (1.5rem) roundedness. Cards should feel like soft, "pillowy" containers.

### Input Fields
- Avoid "boxed" inputs. Use a "Soft Underline" approach or a very subtle `surface-container-highest` (`#e3e3db`) fill with `md` (0.75rem) corners.
- Error states use `error` (`#a73b21`) for text and a 5% `error_container` fill.

### Specialized Components
- **The "Prayer Pulse":** A glassmorphic card for the upcoming prayer time, using `primary-container` (`#d7e7d6`) as a soft glow effect behind the text.
- **Dhikr Counter:** A large, circular `surface-container-highest` element that uses a `primary` stroke to indicate progress, emphasizing haptic feedback over heavy visual lines.

---

## 6. Do’s and Don’ts

### Do:
- **Do** use asymmetrical margins (e.g., a wider left margin for titles) to create an editorial, high-end feel.
- **Do** use `primary_fixed_dim` (`#c9d9c9`) for subtle "active" states in navigation.
- **Do** prioritize "white space as a feature." If a screen feels cluttered, remove an element rather than shrinking it.

### Don't:
- **Don't** use pure black (`#000000`). Our darkest "on-surface" is a deep, warm charcoal (`#31332e`).
- **Don't** use standard 1px dividers. If you feel the need for a line, try an 8px gap of "empty" space instead.
- **Don't** use "harsh" corners. Use the `lg` (1rem) or `xl` (1.5rem) tokens to maintain the serene, organic aesthetic.