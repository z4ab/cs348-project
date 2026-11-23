# Feature tests on the production database

Features 1-4 were run in the app against the production database (`sql/load_production.sql`, 117,660 games, 25,000 users) on 2026-11-16, and Feature 5 on 2026-11-23. Screenshots are in `docs/screenshots/`. Feature 2 compares release dates with `CURDATE()`, so its rows change with the date the app is run.

To repeat these tests, load the production database, start the backend and frontend (see the README), and open `http://localhost:5173`.

## Feature 1: Search games by title, platform, and genre

Steps:

1. Open the page. The search lists the first 100 releases of all games, sorted by title, with Previous disabled and Next enabled.
2. Type `zelda` in the title box, choose `Nintendo Switch` as the platform, leave the genre as "any genre", and press Search.

Expected: "Releases 1–10" and 10 Switch releases whose titles contain "Zelda", sorted by title, from "Cadence of Hyrule: Crypt of the NecroDancer Featuring the Legend of Zelda" to "The Legend of Zelda: Tears of the Kingdom - Collector's Edition". Previous and Next are both disabled.

![Feature 1](screenshots/feature1-search.png)

## Feature 2: Upcoming releases

Steps:

1. Open the page. With no user chosen, the Upcoming section shows "On all platforms" and the first 100 upcoming releases, earliest first. Undated releases (TBA) come after every dated one.
2. Press Next, then Previous.
3. Type `couchcoop` in the user box and choose `couchcoop`.

Expected:

- Step 1: releases start at the day after today (2026-11-17 on the test date).
- Step 2: Next shows "Releases 101–200", and Previous goes back to "Releases 1–100".
- Step 3: the heading changes to "On couchcoop's platforms, not in their library", the page resets to "Releases 1–100", and only couchcoop's 3 platforms appear (Nintendo Switch, PlayStation 4, Xbox One).
- Clearing the user box goes back to all platforms.

![Feature 2, all platforms, page 2](screenshots/feature2-upcoming-all.png)

![Feature 2, one user's platforms](screenshots/feature2-upcoming-user.png)

## Feature 3: View a library, add a game, and update status/hours

Steps:

1. In the Library section, type `cozygamer` and choose `cozygamer`. Their 14 library entries load, newest first.
2. In the game box, type `Hades II` and choose "Hades II (2024)". Set the status to `playing`, enter `12.5` hours, and press "Add to library".
3. In the new Hades II row, change the status to `completed` and the hours to `40`, then press Save.
4. Choose "Hades II (2024)" in the game box again and press "Add to library".

Expected:

- Step 2: Hades II appears at the top of the library with `playing` and 12.5 hours. The library has 15 entries.
- Step 3: the row shows `completed` and 40 after reloading. The database row is `(7, 228525, 'completed', 40.0)`.
- Step 4: the message "Game is already in this library" appears and nothing is added.

After the test, the entry was removed so the production data matches `data/production/`:

```sql
DELETE FROM library_entry WHERE user_id = 7 AND game_id = 228525;
```

![Feature 3, game picker](screenshots/feature3-library-picker.png)

![Feature 3, after the update and the duplicate add](screenshots/feature3-library-duplicate.png)

## Feature 4: Top-rated games in a genre

Steps:

1. In the "Top rated by genre" section, choose `Shooter`.

Expected: 10 games, ranked by average rating, then number of ratings, then title. All 10 average 10.00. The first three ("The Last Stand: Aftermath", "Valfaris", "Wolfenstein II: The New Colossus") have 3 ratings each, and the other seven have 2.

![Feature 4](screenshots/feature4-top-rated.png)

## Feature 5: Game reviews

Before the test, luckyranger5002's (user 5735) review of Soma was `(5735, 9727, 9, 'Gave up halfway.', '2026-08-03 23:38:10')`. pixelpanda (user 1) had no review of it.

Steps:

1. In the Reviews section, type `Soma` in the game box and choose "Soma (2015)".
2. Type `pixelpanda` in the user box and choose `pixelpanda`. Leave the score and text empty and press Save.
3. Enter `8` as the score and `Great atmosphere.` as the text, then press Save.
4. Type `luckyranger5002` in the user box and choose `luckyranger5002`. Change the score to `6` and the text to `Finished it on a second try.`, then press "Update review".

Expected:

- Step 1: Soma's 13 reviews, newest first, from luckyranger5002 (9, "Gave up halfway.", 2026-08-03) to quietgamer613 (no score, "The story carried it.", 2024-02-09). A review with no score shows `-` in the Score column.
- Step 2: the form is empty and its button says Save, because pixelpanda has no review of Soma. Saving shows "A review needs a score, text, or both" and nothing is added.
- Step 3: pixelpanda's review appears at the top with today's date, the list has 14 reviews, and the button changes to "Update review".
- Step 4: the form starts with luckyranger5002's saved review (9, "Gave up halfway."). After saving, their row shows 6 and the new text with today's date and moves to the top. The list still has 14 reviews, so the edit replaced the review instead of adding a second one.
- Choosing a game with no reviews, such as "Zzzz-Zzzz-Zzzz (2017)", shows "No reviews yet".

After the test, pixelpanda's review was removed and luckyranger5002's was restored, so the production data matches `data/production/`:

```sql
DELETE FROM review WHERE user_id = 1 AND game_id = 9727;
UPDATE review SET score = 9, body = 'Gave up halfway.', created_at = '2026-08-03 23:38:10'
WHERE user_id = 5735 AND game_id = 9727;
```

![Feature 5, Soma's reviews](screenshots/feature5-reviews-list.png)

![Feature 5, saving an empty review](screenshots/feature5-reviews-empty.png)

![Feature 5, pixelpanda's new review](screenshots/feature5-reviews-new.png)

![Feature 5, luckyranger5002's edited review](screenshots/feature5-reviews-edit.png)

## Problems found on production data and their fixes

Response sizes and times are from `curl` against the local backend.

| # | Problem | Fix |
|---|---|---|
| P1 | `GET /api/upcoming` with no user returned all 22,007 upcoming releases (1.7 MB) in one response. | 100 rows per page with Previous and Next, as in Feature 1. The first page is 10.7 KB in 0.14 s. |
| P2 | In that list, the 17,955 undated releases sorted first because MySQL sorts `NULL` before dates. The first 180 pages would have been TBA. | Order by `gp.release_date IS NULL` first, so undated releases come last. |
| P3 | `GET /api/upcoming?user_id=N` returned all of a user's upcoming releases (2,590 rows for user 1). | Paged the same way. |
| P4 | Upcoming rows were keyed by title and platform. 34 title and platform pairs among upcoming releases belong to more than one game (69 rows, one pair shared by 3 games), which gives duplicate React keys. | `g.game_id` is now returned and used in the key, and added to `ORDER BY` so the order is total across pages. |
| P5 | `GET /api/users` returned all 25,000 users (1.1 MB), and the Upcoming and Library sections each rendered them as a 25,000-option dropdown. | Replaced both dropdowns with a type-to-search user picker. `GET /api/users?q=` returns up to 10 usernames starting with `q`, which can use the `UNIQUE` index on `username` (0.04 s). |

Not changed, but seen on production data:

- An empty search (Feature 1) takes about 0.9 s, because it sorts all 234,882 releases by title to return the first 100. This is left for the production performance work (#4).
- Feature 4's top 10 in every genre tested is games with a 10.00 average from 2-3 synthetic reviews. The query does what the report says. A minimum number of ratings would make the ranking more useful, but that changes the feature's definition.
