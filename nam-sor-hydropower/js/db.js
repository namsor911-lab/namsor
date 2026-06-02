const RECEIPT_DB_NAME = 'namSorReceiptDB';
const RECEIPT_STORE = 'receipts';

function openReceiptDB() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(RECEIPT_DB_NAME, 1);
    request.onupgradeneeded = (event) => {
      const db = event.target.result;
      if (!db.objectStoreNames.contains(RECEIPT_STORE)) {
        db.createObjectStore(RECEIPT_STORE, { keyPath: 'id', autoIncrement: true });
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

function saveReceipt(item) {
  return openReceiptDB().then((db) => {
    return new Promise((resolve, reject) => {
      const tx = db.transaction(RECEIPT_STORE, 'readwrite');
      const store = tx.objectStore(RECEIPT_STORE);
      store.put(item);
      tx.oncomplete = () => resolve(item);
      tx.onerror = () => reject(tx.error);
    });
  });
}

function getReceipt(id) {
  return openReceiptDB().then((db) => {
    return new Promise((resolve, reject) => {
      const tx = db.transaction(RECEIPT_STORE, 'readonly');
      const store = tx.objectStore(RECEIPT_STORE);
      const request = store.get(Number(id));
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  });
}

function deleteReceipt(id) {
  return openReceiptDB().then((db) => {
    return new Promise((resolve, reject) => {
      const tx = db.transaction(RECEIPT_STORE, 'readwrite');
      const store = tx.objectStore(RECEIPT_STORE);
      store.delete(Number(id));
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
  });
}

function save(key, value) {
  window.localStorage.setItem(key, JSON.stringify(value));
}

function load(key, fallback = null) {
  const raw = window.localStorage.getItem(key);
  if (!raw) return fallback;
  try {
    return JSON.parse(raw);
  } catch (error) {
    return fallback;
  }
}

function recalc() {
  const entries = load('accountingEntries', []);
  const total = entries.reduce((sum, item) => sum + Number(item.amount || 0) * (item.type === 'expense' ? -1 : 1), 0);
  document.getElementById('totalBalance').textContent = fmt(total);
  document.getElementById('openingBalance').textContent = fmt(openingBal());
  return totalBal();
}

function openingBal() {
  return Number(load('openingBalance', 0));
}

function totalBal() {
  const balance = recalc();
  return openingBal() + balance;
}

window.save = save;
window.load = load;
window.openReceiptDB = openReceiptDB;
window.saveReceipt = saveReceipt;
window.getReceipt = getReceipt;
window.deleteReceipt = deleteReceipt;
window.recalc = recalc;
window.openingBal = openingBal;
window.totalBal = totalBal;
