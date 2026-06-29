import { useMediaQuery } from '@vueuse/core'

const MOBILE_BREAKPOINT = '(max-width: 768px)'

/**
 * Reactive composable that returns true when viewport width < 768px.
 * Consistent with SidebarProvider's internal isMobile detection.
 */
export function useIsMobile() {
  return useMediaQuery(MOBILE_BREAKPOINT)
}
