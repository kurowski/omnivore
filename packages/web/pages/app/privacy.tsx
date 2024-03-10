import { PrivacyPolicy } from '../../components/templates/PrivacyPolicy'
import { applyStoredTheme } from '../../lib/themeUpdater'

export default function Privacy(): JSX.Element {
  applyStoredTheme()
  return <PrivacyPolicy isAppEmbed />
}
