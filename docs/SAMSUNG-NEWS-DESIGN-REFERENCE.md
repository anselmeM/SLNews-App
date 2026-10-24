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

## App bar, sections and cards (measured)

| Element | Samsung resource | Value | SLNews |
| --- | --- | --- | --- |
| Detail app bar | `news_detail_appbar_height` | 72 dp (56 dp with cover) | 56 dp branded toolbar |
| Toolbar title | `news_detail_toolbar_title_text_size` | 21 sp | 21 sp brand mark |
| Back icon box | `news_detail_appbar_back_icon_width` | 56 dp, start 20 / end 12 | 48 dp tap target |
| Toolbar padding top | `news_detail_appbar_padding_top` | 8 dp | `AppSpacing.sm` |
| Logo | `news_detail_appbar_logo_height` | 22 dp | 21 sp wordmark |
| Toolbar start inset | `main_tab_toolbar_inset_start` | 20 dp | `AppSpacing.xl` |
| Sub-header height | `news_widget_list_sub_header_height` | 56 dp | section header 20/16/20/8 padding |
| Sub-header text | `news_widget_list_sub_header_text_size` | 19 sp | `sectionTitle` 22 sp (hero-scale on feed) |
| Widget toolbar | `news_widget_configure_toolbar_height` | 64 dp | — |
| Widget title | `news_widget_configure_toolbar_title_size` | 21 sp | — |
| 4:3 tile title cap | `news_4_3_tile_wide_title_height` | 60 dp (100 dp narrow, 52 dp large) | image ratio ~0.87 in carousel |
| Widget card titles | `news_widget_title_text_size_*` | 16 / 18 / 20 sp | `cardTitle` 18 sp |
| List item title gap | `news_widget_list_item_title_margin_bottom` | 8 dp | 6 dp |

The hero card ratio was set from the reference screenshot: an 872 px wide card at
1,000 px tall on a 2340 px screen (≈0.87), which maps to a 380 dp carousel height
on a 393 dp-wide phone.

## Bottom navigation, chips and scrim

| Element | Samsung resource | Value | SLNews |
| --- | --- | --- | --- |
| Nav height | `design_bottom_navigation_height` | 56 dp | `NavigationBar` height 64 → **56 dp** |
| Nav icon | `design_bottom_navigation_icon_size` | 24 dp | 24 dp |
| Nav label | `design_bottom_navigation_text_size` | 12 sp (active 14) | `navLabel` 12 sp / 600 |
| Nav item bounds | `design_bottom_navigation_item_max_width` | 96 dp (active 168) | four equal items |
| Nav elevation | `design_bottom_navigation_elevation` | 8 dp | flat, 0.5 dp top hairline |
| Chip height | `chip_height` | **32 dp** | `FollowChip` 32 dp |
| Chip text | `chip_text_size` | 14 sp | 14 sp |
| Chip gaps | `chip_spacing_horizontal` | 8 dp | 8–10 dp |
| Chip group padding | `chip_group_*_padding` | 6 dp | 6 dp |
| Cover fade edge | `cover_bottom_fading_edge_length` | **84 dp** | hero scrim 45 % → bottom |
| Cover scrim | `news_widget_4x2_gradation_cover` | `#05171717 → #B3171717`, angle 270 | same stops |

The scrim drawable is `res/jEd.xml`: `startColor=#05171717`, `endColor=#B3171717`,
`angle=270` — a 2 % to 70 % wash of `#171717`, not pure black.

## Reader, list rows and ad card

| Element | Samsung resource | Value | SLNews |
| --- | --- | --- | --- |
| Detail app bar | `news_detail_appbar_height` | **72 dp** (56 dp cover) | reader `SliverAppBar` 72 dp |
| Detail title | `news_detail_toolbar_title_text_size` | 21 sp | publisher mark 22 dp |
| Back icon box | `news_detail_appbar_back_icon_width` | 56 dp (start 20 / end 12) | 56 dp |
| Toolbar top pad | `news_detail_appbar_padding_top` | 8 dp | 8 dp |
| List item radius | `news_widget_list_item_radius` | 18 dp | 20 dp card |
| List item side margin | `news_widget_list_item_margin_side` | 10 dp | 12 dp page gutter |
| List item padding | `news_widget_list_item_padding_*` | 16 dp | 16 dp |
| Title gap | `news_widget_list_item_title_margin_bottom` | 8 dp | 8 dp |
| List divider | `news_widget_list_item_divider` | 10 dp | 12 dp |
| Ad scrim | `news_banner_ad_gradient_*` | `#0D000000 → #33000000` | bottom scrim 0/55/100 % |
| Ad CTA | `newsBannerAdView_ctaBtn_*` | 30 dp high, radius 15 | 30 dp / 15 dp |
| Ad title | `newsBannerAdView_title_textSize` | 16 dp | 24 sp hero (kept) |
| Ad badge | `newsBannerAdView_adBadge_textSize` | 12 dp | 12 sp “AD” |
