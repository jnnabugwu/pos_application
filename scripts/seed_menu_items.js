// Seeds random menuItems docs into the real Firestore project, matching the
// schema MenuItem.fromMap expects (packages/core/lib/entities/menu_item.dart).
//
// Usage:
//   cd scripts && npm install firebase-tools --no-save && node seed_menu_items.js
//
// Requires an existing `firebase login` session (see docs/architecture-decisions.md
// — "Seeding Firestore data without a service-account key" — for why this reuses
// that login instead of a downloaded key). Re-running adds more docs; it does not
// dedupe against what's already there.

const auth = require('firebase-tools/lib/auth.js');
const scopes = require('firebase-tools/lib/scopes.js');

const PROJECT_ID = 'pos-application-90299';
const ITEM_COUNT = 24;

const MENU = {
  Drinks: [
    'Drip Coffee', 'Cappuccino', 'Latte', 'Cold Brew', 'Espresso',
    'Iced Tea', 'Chai Latte', 'Hot Chocolate', 'Sparkling Water', 'Orange Juice',
  ],
  Food: [
    'Turkey Club Sandwich', 'Veggie Wrap', 'Grilled Cheese', 'Caesar Salad',
    'Avocado Toast', 'Breakfast Burrito', 'Margherita Flatbread', 'Chicken Panini',
  ],
  Desserts: [
    'Chocolate Chip Cookie', 'Blueberry Muffin', 'Cinnamon Roll', 'Brownie',
    'Cheesecake Slice', 'Croissant',
  ],
  Snacks: [
    'Trail Mix', 'Kettle Chips', 'Granola Bar', 'Fresh Fruit Cup',
  ],
};

const PRICE_RANGE_CENTS = {
  Drinks: [250, 550],
  Food: [650, 1250],
  Desserts: [300, 600],
  Snacks: [200, 450],
};

function randomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function buildRandomItems(count) {
  const categories = Object.keys(MENU);
  const pool = [];
  for (const category of categories) {
    for (const name of MENU[category]) {
      pool.push({ category, name });
    }
  }
  // Shuffle then take `count` (pool has 28 entries, comfortably >= 20).
  for (let i = pool.length - 1; i > 0; i--) {
    const j = randomInt(0, i);
    [pool[i], pool[j]] = [pool[j], pool[i]];
  }
  return pool.slice(0, count).map(({ category, name }) => {
    const [min, max] = PRICE_RANGE_CENTS[category];
    return {
      name,
      category,
      priceCents: randomInt(min, max),
      // ~85% available, rest unavailable, so the toggle UI has something to show.
      available: Math.random() < 0.85,
      stockCount: randomInt(0, 40),
    };
  });
}

function toFirestoreDocument(item, now) {
  return {
    fields: {
      name: { stringValue: item.name },
      category: { stringValue: item.category },
      priceCents: { integerValue: String(item.priceCents) },
      available: { booleanValue: item.available },
      stockCount: { integerValue: String(item.stockCount) },
      createdAt: { timestampValue: now },
      updatedAt: { timestampValue: now },
    },
  };
}

async function main() {
  const account = auth.getGlobalDefaultAccount();
  if (!account) {
    throw new Error('No firebase CLI login found — run `firebase login` first.');
  }
  console.log(`Using Firebase CLI session for ${account.user.email}`);

  const token = await auth.getAccessToken(account.tokens.refresh_token, [
    scopes.CLOUD_PLATFORM,
  ]);

  const items = buildRandomItems(ITEM_COUNT);
  const now = new Date().toISOString();
  const baseUrl = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/menuItems`;

  let created = 0;
  for (const item of items) {
    const res = await fetch(baseUrl, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token.access_token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(toFirestoreDocument(item, now)),
    });
    if (!res.ok) {
      const body = await res.text();
      throw new Error(`Failed to create "${item.name}": ${res.status} ${body}`);
    }
    created += 1;
    console.log(`  + [${item.category}] ${item.name} — $${(item.priceCents / 100).toFixed(2)} — ${item.stockCount} in stock${item.available ? '' : ' (unavailable)'}`);
  }

  console.log(`\nSeeded ${created} menuItems documents into ${PROJECT_ID}.`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
