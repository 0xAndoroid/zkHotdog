import React from "react";
import { HeartIcon } from "@heroicons/react/24/outline";
import { SwitchTheme } from "~~/components/SwitchTheme";

/**
 * Site footer
 */
export const Footer = () => {
  return (
    <div className="min-h-0 py-5 px-1 mb-11 lg:mb-0">
      <div>
        <div className="fixed flex justify-between items-center w-full z-10 p-4 bottom-0 left-0 pointer-events-none">
          <SwitchTheme className={`pointer-events-auto self-end md:self-auto`} />
        </div>
      </div>
      <div className="w-full">
        <ul className="menu menu-horizontal w-full">
          <div className="flex justify-center items-center gap-2 text-sm w-full">
            <div className="flex justify-center items-center gap-2">
              <p className="m-0 text-center">
                Built with <HeartIcon className="inline-block h-4 w-4" /> at ETH Denver 2025 by Andrew Tretyakov
              </p>
            </div>
            <span className="m-0 text-center">|</span>
            <div className="text-center">
              <a href="https://github.com/0xAndoroid" target="_blank" rel="noreferrer" className="link">
                Github
              </a>
            </div>
          </div>
        </ul>
      </div>
    </div>
  );
};
