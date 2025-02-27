import React from "react";

// Animation types that can be used
type AnimationType = "loading" | "success" | "error";

interface AnimationObject {
  animation: React.ReactNode;
}

/**
 * Custom hook for providing SVG animations based on the type
 * @param type Animation type to display (loading, success, error)
 * @returns Object containing the animation component
 */
export const UseAnimation = (type: AnimationType): AnimationObject => {
  // Loading/spinner animation
  const loadingAnimation = (
    <svg
      className="animate-spin"
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
      width="100%"
      height="100%"
    >
      <circle
        className="opacity-25"
        cx="12"
        cy="12"
        r="10"
        stroke="currentColor"
        strokeWidth="4"
      ></circle>
      <path
        className="opacity-75"
        fill="currentColor"
        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
      ></path>
    </svg>
  );

  // Success animation (checkmark)
  const successAnimation = (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
      strokeWidth={1.5}
      stroke="currentColor"
      className="text-green-500"
      width="100%"
      height="100%"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
      />
    </svg>
  );

  // Error animation (X)
  const errorAnimation = (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
      strokeWidth={1.5}
      stroke="currentColor"
      className="text-red-500"
      width="100%"
      height="100%"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M9.75 9.75l4.5 4.5m0-4.5l-4.5 4.5M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
      />
    </svg>
  );

  // Return the appropriate animation based on type
  switch (type) {
    case "loading":
      return { animation: loadingAnimation };
    case "success":
      return { animation: successAnimation };
    case "error":
      return { animation: errorAnimation };
    default:
      return { animation: loadingAnimation };
  }
};