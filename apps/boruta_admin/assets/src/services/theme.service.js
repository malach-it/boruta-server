export const themes = [
  {
    id: 'base16-default-light',
    name: 'Default Light',
    dark: false
  },
  {
    id: 'base16-default-dark',
    name: 'Default Dark',
    dark: true
  },
  {
    id: 'solarized-dark',
    name: 'Solarized Dark',
    dark: true
  },
  {
    id: 'solarized-light',
    name: 'Solarized Light',
    dark: false
  },
  {
    id: 'gruvbox-dark-medium',
    name: 'Gruvbox Dark',
    dark: true
  },
  {
    id: 'gruvbox-light-medium',
    name: 'Gruvbox Light',
    dark: false
  },
  {
    id: 'nord',
    name: 'Nord',
    dark: true
  },
]

const themeIds = themes.map(({ id }) => id)
const defaultTheme = 'base16-default-light'
const legacyThemes = {
  aurora: 'base16-default-dark',
  midnight: 'solarized-dark',
  sandstone: 'gruvbox-dark-medium',
  verdant: 'nord',
  glacier: 'solarized-light'
}

export function getTheme () {
  const savedTheme = localStorage.getItem('admin_theme')

  if (themeIds.includes(savedTheme)) return savedTheme
  if (legacyThemes[savedTheme]) return legacyThemes[savedTheme]

  return JSON.parse(localStorage.getItem('dark_mode') || 'false')
    ? 'base16-default-dark'
    : defaultTheme
}

export function setTheme (theme, notify = true) {
  const nextTheme = themeIds.includes(theme) ? theme : defaultTheme

  document.documentElement.dataset.adminTheme = nextTheme
  localStorage.setItem('admin_theme', nextTheme)
  localStorage.removeItem('dark_mode')

  if (notify) {
    window.dispatchEvent(new CustomEvent('admin-theme-change', {
      detail: nextTheme
    }))
  }

  return nextTheme
}
