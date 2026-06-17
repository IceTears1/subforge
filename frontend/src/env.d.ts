/// <reference types="vite/client" />

declare module '*.vue' {
  import type { DefineComponent } from 'vue'
  const component: DefineComponent<{}, {}, any>
  export default component
}

declare module '@vicons/ionicons5' {
  import type { Component } from 'vue'
  export const PersonOutline: Component
  export const LockClosedOutline: Component
  export const MenuOutline: Component
  export const GridOutline: Component
  export const CloudOutline: Component
  export const SwapHorizontalOutline: Component
  export const PeopleOutline: Component
  export const SettingsOutline: Component
  export const AddOutline: Component
  export const RefreshOutline: Component
  export const TrashOutline: Component
  export const EyeOutline: Component
  export const PersonAddOutline: Component
  export const ServerOutline: Component
  export const GlobeOutline: Component
  export const PulseOutline: Component
}
