import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const commentsPath = resolve(here, '../../assets/comments.json');
const apply = process.argv.includes('--apply');
const projectId = process.env.FIREBASE_PROJECT_ID?.trim();

const source = JSON.parse(await readFile(commentsPath, 'utf8'));
const groups = Object.entries(source).map(([key, values]) => {
  if (!Array.isArray(values) || values.length === 0) {
    throw new Error(`コメントが空です: ${key}`);
  }

  const comments = values.map((value) => value.text).filter(Boolean);
  if (comments.length !== values.length) {
    throw new Error(`text がないコメントがあります: ${key}`);
  }

  return {
    id: encodeURIComponent(key),
    key,
    species: values[0].species,
    personality: values[0].personality,
    comments,
    count: comments.length,
  };
});

const total = groups.reduce((sum, group) => sum + group.count, 0);
console.log(`検証完了: ${groups.length}グループ / ${total}コメント`);

if (!apply) {
  console.log('ドライランです。Firestoreへの書き込みは行っていません。');
  console.log('書き込む場合は FIREBASE_PROJECT_ID を設定して npm run import を実行してください。');
  process.exit(0);
}

if (!projectId) {
  throw new Error('FIREBASE_PROJECT_ID が必要です。');
}

const { applicationDefault, initializeApp } = await import('firebase-admin/app');
const { FieldValue, getFirestore } = await import('firebase-admin/firestore');

initializeApp({ credential: applicationDefault(), projectId });
const firestore = getFirestore();

for (let offset = 0; offset < groups.length; offset += 400) {
  const batch = firestore.batch();
  for (const group of groups.slice(offset, offset + 400)) {
    const reference = firestore.collection('comment_groups').doc(group.id);
    batch.set(
      reference,
      {
        ...group,
        schemaVersion: 1,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }
  await batch.commit();
}

console.log(`Firestore (${projectId}) に ${groups.length}グループを書き込みました。`);
