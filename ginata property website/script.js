'use strict';

const header = document.querySelector('#site-header');
const menuToggle = document.querySelector('.menu-toggle');
const navigation = document.querySelector('#site-nav');

function closeMenu() {
  navigation.classList.remove('open');
  menuToggle.setAttribute('aria-expanded', 'false');
  menuToggle.setAttribute('aria-label', 'Open navigation');
}

menuToggle.addEventListener('click', () => {
  const isOpen = menuToggle.getAttribute('aria-expanded') === 'true';
  if (isOpen) {
    closeMenu();
  } else {
    navigation.classList.add('open');
    menuToggle.setAttribute('aria-expanded', 'true');
    menuToggle.setAttribute('aria-label', 'Close navigation');
  }
});

navigation.querySelectorAll('a, button').forEach(element => element.addEventListener('click', closeMenu));
document.addEventListener('click', event => {
  if (!header.contains(event.target)) closeMenu();
});
document.addEventListener('keydown', event => {
  if (event.key === 'Escape' && navigation.classList.contains('open')) {
    closeMenu();
    menuToggle.focus();
  }
});
window.matchMedia('(min-width: 681px)').addEventListener('change', closeMenu);
const updateHeader = () => header.classList.toggle('scrolled', window.scrollY > 16);
window.addEventListener('scroll', updateHeader, { passive: true });
updateHeader();

const privacyDialog = document.querySelector('#privacy-dialog');

function openDialog(dialog) {
  closeMenu();
  dialog.showModal();
  document.body.classList.add('modal-open');
}

document.querySelector('#privacy-button').addEventListener('click', () => openDialog(privacyDialog));
document.querySelectorAll('dialog').forEach(dialog => {
  dialog.querySelectorAll('[data-close-dialog]').forEach(button => {
    button.addEventListener('click', () => dialog.close());
  });
  dialog.addEventListener('click', event => {
    if (event.target !== dialog) return;
    const bounds = dialog.getBoundingClientRect();
    if (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom) {
      dialog.close();
    }
  });
  dialog.addEventListener('close', () => document.body.classList.remove('modal-open'));
});

const tabs = [...document.querySelectorAll('[role="tab"]')];
const panels = [...document.querySelectorAll('[role="tabpanel"]')];

function selectTab(name, focus = false) {
  tabs.forEach(tab => {
    const selected = tab.dataset.tab === name;
    tab.setAttribute('aria-selected', String(selected));
    tab.tabIndex = selected ? 0 : -1;
    if (selected && focus) tab.focus();
  });
  panels.forEach(panel => { panel.hidden = panel.id !== `panel-${name}`; });
  document.querySelectorAll('.side-tab').forEach(button => {
    const selected = button.dataset.previewTarget === name;
    button.classList.toggle('active', selected);
    button.setAttribute('aria-pressed', String(selected));
  });
}

tabs.forEach((tab, index) => {
  tab.addEventListener('click', () => selectTab(tab.dataset.tab));
  tab.addEventListener('keydown', event => {
    let nextIndex;
    if (event.key === 'ArrowRight') nextIndex = (index + 1) % tabs.length;
    else if (event.key === 'ArrowLeft') nextIndex = (index - 1 + tabs.length) % tabs.length;
    else if (event.key === 'Home') nextIndex = 0;
    else if (event.key === 'End') nextIndex = tabs.length - 1;
    else return;
    event.preventDefault();
    selectTab(tabs[nextIndex].dataset.tab, true);
  });
});
document.querySelectorAll('[data-preview-target]').forEach(button => {
  button.addEventListener('click', () => selectTab(button.dataset.previewTarget, true));
});
selectTab('overview');

const calendarDays = document.querySelector('#calendar-days');
const calendarMonth = document.querySelector('#calendar-month');
let visibleMonth = new Date(2026, 10, 1);
let selectedDate = new Date(2026, 10, 11);
const sampleEvents = {
  '2026-11-11': [
    { title: 'Wanjiku arrives at Garden Loft', detail: 'Check-in · 2 guests · 15:00' },
    { title: 'David departs from The Riverside', detail: 'Check-out · 1 guest · 11:00' },
  ],
  '2026-11-14': [{ title: 'Wanjiku departs from Garden Loft', detail: 'Check-out · 2 guests · 11:00' }],
  '2026-11-15': [{ title: 'Njeri arrives at Palm Cottage', detail: 'Check-in · 3 guests · 15:00' }],
  '2026-11-18': [{ title: 'Njeri departs from Palm Cottage', detail: 'Check-out · 3 guests · 11:00' }],
};

function dateKey(date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

function updateDayDetail() {
  document.querySelector('#selected-date').textContent = selectedDate.toLocaleDateString('en-GB', {
    weekday: 'long', day: 'numeric', month: 'long', year: 'numeric',
  }).toUpperCase();
  const events = sampleEvents[dateKey(selectedDate)] || [];
  document.querySelector('#day-title').textContent = events.length > 1
    ? 'Two moments to plan for.'
    : events.length === 1 ? 'One guest. A thoughtful moment.' : 'A little breathing room.';
  const eventList = document.querySelector('#day-events');
  eventList.replaceChildren();
  if (events.length === 0) {
    const message = document.createElement('p');
    message.className = 'demo-hint';
    message.textContent = 'No sample arrivals or departures on this day. Try 11, 14, 15 or 18 November 2026.';
    eventList.append(message);
    return;
  }
  events.forEach(event => {
    const card = document.createElement('div');
    card.className = 'day-event';
    const title = document.createElement('strong');
    title.textContent = event.title;
    const detail = document.createElement('span');
    detail.textContent = event.detail;
    card.append(title, detail);
    eventList.append(card);
  });
}

function renderCalendar() {
  const year = visibleMonth.getFullYear();
  const month = visibleMonth.getMonth();
  calendarMonth.textContent = visibleMonth.toLocaleDateString('en-GB', { month: 'long', year: 'numeric' });
  calendarDays.replaceChildren();
  const mondayOffset = (new Date(year, month, 1).getDay() + 6) % 7;
  const lastDay = new Date(year, month + 1, 0).getDate();
  for (let index = 0; index < mondayOffset; index++) {
    const emptyDay = document.createElement('span');
    emptyDay.setAttribute('aria-hidden', 'true');
    calendarDays.append(emptyDay);
  }
  for (let day = 1; day <= lastDay; day++) {
    const date = new Date(year, month, day);
    const button = document.createElement('button');
    const key = dateKey(date);
    button.type = 'button';
    button.textContent = String(day);
    const booked = year === 2026 && month === 10 && day >= 11 && day <= 18;
    button.classList.toggle('booked', booked);
    button.setAttribute('aria-pressed', String(key === dateKey(selectedDate)));
    button.setAttribute('aria-label', `${date.toLocaleDateString('en-GB', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })}${sampleEvents[key] ? ', sample guest movement' : ''}`);
    button.addEventListener('click', () => {
      selectedDate = date;
      calendarDays.querySelectorAll('button').forEach(dayButton => dayButton.setAttribute('aria-pressed', String(dayButton === button)));
      updateDayDetail();
    });
    calendarDays.append(button);
  }
  updateDayDetail();
}

function changeMonth(offset) {
  visibleMonth = new Date(visibleMonth.getFullYear(), visibleMonth.getMonth() + offset, 1);
  selectedDate = new Date(visibleMonth);
  renderCalendar();
}
document.querySelector('#previous-month').addEventListener('click', () => changeMonth(-1));
document.querySelector('#next-month').addEventListener('click', () => changeMonth(1));
renderCalendar();

const sampleFinances = {
  garden: { gross: 48500, commission: 0, expenses: 7500, paid: 24250 },
  riverside: { gross: 60000, commission: 4000, expenses: 9000, paid: 60000 },
  palm: { gross: 40000, commission: 3000, expenses: 6000, paid: 40000 },
};
const formatKES = value => `KES ${new Intl.NumberFormat('en-KE', { maximumFractionDigits: 2 }).format(value)}`;

function updateFinances() {
  const selected = document.querySelector('#finance-property').value;
  const values = selected === 'all'
    ? Object.values(sampleFinances).reduce((total, property) => ({
      gross: total.gross + property.gross,
      commission: total.commission + property.commission,
      expenses: total.expenses + property.expenses,
      paid: total.paid + property.paid,
    }), { gross: 0, commission: 0, expenses: 0, paid: 0 })
    : sampleFinances[selected];
  document.querySelector('#finance-gross').textContent = formatKES(values.gross);
  document.querySelector('#finance-commission').textContent = `− ${formatKES(values.commission)}`;
  document.querySelector('#finance-expenses').textContent = `− ${formatKES(values.expenses)}`;
  document.querySelector('#finance-profit').textContent = formatKES(values.gross - values.commission - values.expenses);
  document.querySelector('#finance-paid').textContent = formatKES(values.paid);
  document.querySelector('#finance-balance').textContent = formatKES(values.gross - values.paid);
}
document.querySelector('#finance-property').addEventListener('change', updateFinances);
updateFinances();

const messages = {
  welcome: {
    title: 'A warm welcome',
    text: "Hi [Guest name], we're so happy you'll be staying with us at [Property name]! Your space will be ready from [Check-in time] on [Date]. We'll send your arrival details before your stay. If you have any questions, just ask. See you soon!",
  },
  checkin: {
    title: 'Check-in made simple',
    text: "Hello [Guest name], your stay at [Property name] is nearly here! You'll find us at [Address]. Check-in is from [Time], and your access instructions are [Instructions]. Wi-Fi: [Network] / [Password]. Make yourself at home, and let us know if you need anything.",
  },
  checkout: {
    title: 'Until next time',
    text: "Hi [Guest name], we hope you've felt at home at [Property name]. A little reminder that check-out is by [Time] tomorrow. Please [Key return instructions]. Thank you for choosing to stay with us. We'd love to welcome you back!",
  },
};
let selectedMessage = 'welcome';
const messageEditor = document.querySelector('#message-content');
const copyStatus = document.querySelector('#copy-status');
const copyButton = document.querySelector('#copy-message');

document.querySelectorAll('[data-message]').forEach(button => {
  button.addEventListener('click', () => {
    selectedMessage = button.dataset.message;
    document.querySelector('#message-title').textContent = messages[selectedMessage].title;
    messageEditor.value = messages[selectedMessage].text;
    copyStatus.textContent = '';
    document.querySelectorAll('[data-message]').forEach(option => {
      const active = option === button;
      option.classList.toggle('selected', active);
      option.setAttribute('aria-pressed', String(active));
    });
  });
});
messageEditor.addEventListener('input', () => {
  messages[selectedMessage].text = messageEditor.value;
  copyStatus.textContent = '';
});
copyButton.addEventListener('click', async () => {
  if (!messageEditor.value.trim()) {
    copyStatus.textContent = 'Add a message before copying.';
    messageEditor.focus();
    return;
  }
  copyButton.disabled = true;
  try {
    if (!navigator.clipboard?.writeText) throw new Error('Clipboard unavailable');
    await navigator.clipboard.writeText(messageEditor.value);
    copyStatus.textContent = 'Copied. Personalise the placeholders, then paste it where you chat.';
  } catch {
    messageEditor.focus();
    messageEditor.select();
    copyStatus.textContent = 'Your message is selected. Use your device’s Copy command.';
  } finally {
    copyButton.disabled = false;
  }
});

document.querySelector('#year').textContent = String(new Date().getFullYear());
const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
if ('IntersectionObserver' in window && !reducedMotion.matches) {
  document.documentElement.classList.add('js-reveal');
  const observer = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: 0.08 });
  document.querySelectorAll('.reveal').forEach(element => observer.observe(element));
}
