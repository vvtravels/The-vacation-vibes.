const navToggle = document.getElementById('navToggle');
const navLinks = document.getElementById('navLinks');
const navBackdrop = document.getElementById('navBackdrop');

function closeMenu() {
  navLinks.classList.remove('open');
  navToggle.classList.remove('active');
  navBackdrop.classList.remove('show');
  document.body.classList.remove('no-scroll');
  navToggle.setAttribute('aria-expanded', 'false');
}

navToggle.addEventListener('click', () => {
  const open = navLinks.classList.toggle('open');
  navToggle.classList.toggle('active', open);
  navBackdrop.classList.toggle('show', open);
  document.body.classList.toggle('no-scroll', open);
  navToggle.setAttribute('aria-expanded', open);
});

navBackdrop.addEventListener('click', closeMenu);

document.addEventListener('keydown', e => {
  if (e.key === 'Escape') closeMenu();
});

navLinks.querySelectorAll('a').forEach(link => {
  link.addEventListener('click', closeMenu);
});

async function bookTrip() {
  const pickup = document.getElementById('pickup').value;
  const drop = document.getElementById('drop').value;
  const travelDate = document.getElementById('travelDate').value;
  const vehicle = document.getElementById('vehicle').value;
  const passengers = document.getElementById('passengers').value;
  const customerName = document.getElementById('customerName').value;
  const customerPhone = document.getElementById('customerPhone').value;

  if (!pickup || !drop || !customerName || !customerPhone || !vehicle) {
    alert('Please fill in pickup, drop, your name, phone number, and choose a vehicle.');
    return;
  }

  try {
    await fetch('/api/bookings', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        pickup, drop, travelDate, vehicle, passengers, customerName, customerPhone
      })
    });
  } catch (err) {
    console.error('Could not save booking:', err);
  }

  const message =
`Hello Vacation Vibes Tours and Travels,

I would like to book a trip.

Name: ${customerName}
Phone: ${customerPhone}
Pickup: ${pickup}
Drop: ${drop}
Travel Date: ${travelDate}
Vehicle: ${vehicle}
Passengers: ${passengers}`;

  const whatsappNumber = '919585945565';

  const url =
`https://wa.me/${whatsappNumber}?text=${encodeURIComponent(message)}`;

  window.open(url, '_blank');
}
window.addEventListener('load', () => {
  const loader = document.getElementById('loader');
  loader.style.opacity = '0';
  loader.style.transition = 'opacity 0.6s ease';

  setTimeout(() => {
    loader.style.display = 'none';
  }, 600);
});