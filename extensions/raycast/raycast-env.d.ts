/// <reference types="@raycast/api">

/* 🚧 🚧 🚧
 * This file is auto-generated from the extension's manifest.
 * Do not modify manually. Instead, update the `package.json` file.
 * 🚧 🚧 🚧 */

/* eslint-disable @typescript-eslint/ban-types */

type ExtensionPreferences = {
  /** GhostTile Binary Path - Optional absolute path to the ghosttile CLI. */
  "ghosttilePath"?: string
}

/** Preferences accessible in all the extension's commands */
declare type Preferences = ExtensionPreferences

declare namespace Preferences {
  /** Preferences accessible in the `ghosttile-apps` command */
  export type GhosttileApps = ExtensionPreferences & {}
}

declare namespace Arguments {
  /** Arguments passed to the `ghosttile-apps` command */
  export type GhosttileApps = {}
}

