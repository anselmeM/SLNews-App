# Samsung News — design reference (from the APK)

Measured with `aapt2 dump resources` on `com.samsung.android.app.spage` 7.7.02.2
(7.7.02.2, minSdk 26, targetSdk 36). This is a **measurement document**: no Samsung
assets, code or fonts are copied into SLNews.

## Layout constants

| Token (Samsung) | Value | SLNews mapping |
| --- | --- | --- |
| `news_base_side_margin` | **10 dp** | `AppSpacing.page` = 12 dp (4 pt grid, avoids cramped body copy) |
| card radius | ~20 dp (SESL cards) | `AppRadius.lg` = 20 dp |
| detail app bar height | 72 dp (56 dp with cover) | app bar height 56 dp + 8 dp top padding |
| detail app bar title | **21 sp** | `groupTitle` 18–21 sp by surface |
| feed card title | 14–17 sp, Sec600/700 | `cardTitle` 18 sp, w700 |
| list item divider | 10 dp | feed gap 12 dp |
| ad banner title | 16 dp | `AdCard` headline 24 sp (hero, not banner) |
| ad badge | 12 dp, 19×20 dp | “AD” overline, 11–12 sp, letter-spacing 1.2 |
| ad CTA | 30 dp high, radius 15 dp | pill CTA 30–36 dp high |
| widget list footer | 37 dp | row action rail ~36 dp |

## Colour tokens

| Role | Light | Dark |
| --- | --- | --- |
| Ink | `#010102` | `#FAFAFF` |
| Paper | `#FAFAFF` / white | `#010102` |
| Muted ink | `#4D4D52` | `#CCCCCC` |
| Faint ink | `#8C8C8C` | — |
| Accent blue | `#376FDE` / `#387AFF` | — |
| Trending gradient | `#4533A3 → #3972B5` | — |
| Ad scrim | `#0D000000 → #33000000`, CTA `#52000000` | — |
| Widget night bg | — | `#2D2D30` (60 % alpha) |

## Type

Samsung uses the **Sec** (One UI Sans) family at weights **400/600/700**.
SLNews ships Inter, which is the closest metric match we can licence; the token
sizes above were adopted, not the font.

## What was applied to SLNews

- Page gutter 16 → **12 dp**; row vertical padding 14 → **12 dp**.
- Card radius 16 → **20 dp**.
- Type: `screenTitle` 32, `sectionTitle` 22, `groupTitle`/`cardTitle` 18.
- Ink `#010102`, canvas `#F2F2F3`, primary `#387AFF` (dark `#6C9DFF`).
- Ad card: “AD” overline with 1.2 letter-spacing, 24 sp headline.

## Sources (resource names in the APK)

`news_base_side_margin`, `news_detail_appbar_height`, `news_detail_toolbar_title_text_size`,
`newsBannerAdView_adBadge_textSize`, `newsBannerAdView_ctaBtn_cornerRadius`,
`news_widget_list_item_divider`, `news_glance_title_*`, `news_widget_*` colours,
`style/NewsWidget.Card.*.TextStyle` (Sec600/700).
