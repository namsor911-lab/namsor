function fmt(value) {
  const number = Number(value || 0);
  return number.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function fmtAbs(value) {
  return fmt(Math.abs(Number(value || 0)));
}

function showToast(message, duration = 3000) {
  const toast = document.getElementById('toast');
  toast.textContent = message;
  toast.classList.add('visible');
  window.clearTimeout(showToast.timeoutId);
  showToast.timeoutId = window.setTimeout(() => toast.classList.remove('visible'), duration);
}

function go(selector) {
  const target = document.querySelector(selector);
  if (target) target.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

function toggleSidebar() {
  document.body.classList.toggle('sidebar-open');
}

function buildYears(selectId, startYear = 2020) {
  const select = document.getElementById(selectId);
  if (!select) return;
  const currentYear = new Date().getFullYear();
  select.innerHTML = '';
  for (let year = currentYear; year >= startYear; year -= 1) {
    const option = document.createElement('option');
    option.value = String(year);
    option.textContent = String(year);
    select.appendChild(option);
  }
}

function comingSoon() {
  showToast('This feature is coming soon.');
}
