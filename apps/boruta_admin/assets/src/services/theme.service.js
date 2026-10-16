export const themes = [
  {
    id: 'boruta-default-light',
    name: 'Boruta Default Light',
    dark: false
  },
  {
    id: 'boruta-default-dark',
    name: 'Boruta Default Dark',
    dark: true
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
const defaultTheme = 'boruta-default-light'
const legacyThemes = {
  aurora: 'boruta-default-dark',
  midnight: 'boruta-default-dark',
  sandstone: 'gruvbox-dark-medium',
  verdant: 'nord',
  glacier: 'boruta-default-light'
}

export function getTheme () {
  const savedTheme = localStorage.getItem('admin_theme')

  if (themeIds.includes(savedTheme)) return savedTheme
  if (legacyThemes[savedTheme]) return legacyThemes[savedTheme]

  return defaultTheme
}

export function setTheme (theme, notify = true) {
  const nextTheme = themeIds.includes(theme) ? theme : defaultTheme

  document.documentElement.dataset.adminTheme = nextTheme
  localStorage.setItem('admin_theme', nextTheme)

  if (notify) {
    window.dispatchEvent(new CustomEvent('admin-theme-change', {
      detail: nextTheme
    }))
  }

  return nextTheme
}
