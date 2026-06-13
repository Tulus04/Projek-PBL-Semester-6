import type { PhantomUiAttributes } from "@aejkatappaja/phantom-ui";

declare module "react/jsx-runtime" {
  export namespace JSX {
    interface IntrinsicElements {
      "phantom-ui": PhantomUiAttributes & React.HTMLAttributes<HTMLElement> & {
        loading?: boolean;
        animation?: "shimmer" | "pulse" | "breathe" | "solid";
        stagger?: number;
        reveal?: number;
        count?: number;
        "count-gap"?: number;
        "shimmer-direction"?: "ltr" | "rtl" | "ttb" | "btt";
        "shimmer-color"?: string;
        "background-color"?: string;
        duration?: number;
        "fallback-radius"?: number;
        debug?: boolean;
        "loading-label"?: string;
        "pierce-shadow"?: boolean;
      };
    }
  }
}

declare global {
  namespace JSX {
    interface IntrinsicElements {
      "phantom-ui": PhantomUiAttributes & React.HTMLAttributes<HTMLElement> & {
        loading?: boolean;
        animation?: "shimmer" | "pulse" | "breathe" | "solid";
        stagger?: number;
        reveal?: number;
        count?: number;
        "count-gap"?: number;
        "shimmer-direction"?: "ltr" | "rtl" | "ttb" | "btt";
        "shimmer-color"?: string;
        "background-color"?: string;
        duration?: number;
        "fallback-radius"?: number;
        debug?: boolean;
        "loading-label"?: string;
        "pierce-shadow"?: boolean;
      };
    }
  }
}
