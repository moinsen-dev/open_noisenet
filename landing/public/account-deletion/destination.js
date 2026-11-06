document.querySelector('#choose').addEventListener('submit', function (event) {
  event.preventDefault();
  const result = document.querySelector('#target');
  result.replaceChildren();
  try {
    const url = new URL(document.querySelector('#server').value);
    if (url.protocol !== 'https:' || !url.hostname || url.username || url.password || url.search || url.hash) throw new Error();
    const path = url.pathname.replace(/\/+$/, '');
    url.pathname = (path || '/api/v1') + '/auth/account-deletion/web';
    const link = document.createElement('a');
    link.href = url.href;
    link.rel = 'noreferrer';
    link.textContent = 'Löschformular auf ' + url.host + ' öffnen';
    result.append(link);
  } catch {
    result.textContent = 'Bitte eine gültige HTTPS-Adresse ohne Zugangsdaten, Suchparameter oder Fragment eingeben.';
  }
});
