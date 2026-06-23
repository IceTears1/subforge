/// <reference types="vite/client" />

declare module '*.vue' {
  import type { DefineComponent } from 'vue'
  const component: DefineComponent<{}, {}, any>
  export default component
}

declare module '@vicons/ionicons5' {
  import type { Component } from 'vue'
  // Layout menu icons
  export const MenuOutline: Component
  export const GridOutline: Component
  export const CloudOutline: Component
  export const SwapHorizontalOutline: Component
  export const PeopleOutline: Component
  export const SettingsOutline: Component
  export const ServerOutline: Component
  export const GlobeOutline: Component
  export const PulseOutline: Component
  // Theme icons
  export const MoonOutline: Component
  export const SunnyOutline: Component
  // Dashboard icons
  export const KeyOutline: Component
  export const StatsChartOutline: Component
  export const DownloadOutline: Component
  export const AnalyticsOutline: Component
  export const GitCompareOutline: Component
  export const SpeedometerOutline: Component
  export const LayersOutline: Component
  // Auth icons
  export const PersonOutline: Component
  export const LockClosedOutline: Component
  export const PersonAddOutline: Component
  // Action icons
  export const AddOutline: Component
  export const RefreshOutline: Component
  export const TrashOutline: Component
  export const EyeOutline: Component
  export const CopyOutline: Component
  export const OpenOutline: Component
  export const ShieldOutline: Component
  // Subscription icons
  export const CreateOutline: Component
  export const LinkOutline: Component
  export const ShareOutline: Component
  export const CloudUploadOutline: Component
  export const CloudDownloadOutline: Component
  export const DocumentTextOutline: Component
  // Favorite/Monitor icons
  export const StarOutline: Component
  export const TimeOutline: Component
  export const HardwareChipOutline: Component
  export const RocketOutline: Component
  export const WifiOutline: Component
  // Misc
  export const LogoGithub: Component
}
