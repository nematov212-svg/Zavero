import React, { useState } from 'react';
import { Link } from 'react-router-dom';

interface LogoProps {
  className?: string;
  size?: 'sm' | 'md' | 'lg';
  linkTo?: string;
  showSubtitle?: boolean;
}

export const Logo: React.FC<LogoProps> = ({
  className = '',
  size = 'md',
  linkTo = '/',
  showSubtitle = true,
}) => {
  const [imageError, setImageError] = useState(false);

  const sizeMap = {
    sm: { img: 'h-8', text: 'text-lg', fast: 'text-xs', badge: 'text-[9px] px-1.5' },
    md: { img: 'h-11', text: 'text-2xl', fast: 'text-sm', badge: 'text-[10px] px-2' },
    lg: { img: 'h-14', text: 'text-3xl', fast: 'text-base', badge: 'text-xs px-2.5' },
  };

  const content = (
    <div className={`flex items-center gap-2.5 group select-none ${className}`}>
      {!imageError ? (
        <div className="relative flex items-center">
          <img
            src="/zavero-logo.jpg"
            alt="Zavero Fast Logo"
            onError={() => setImageError(true)}
            className={`${sizeMap[size].img} w-auto object-contain rounded-xl shadow-md transition-transform duration-300 group-hover:scale-105`}
          />
        </div>
      ) : (
        /* High-fidelity Vector Fallback matching Image 1 (Noodles Bowl + ZAVERO FAST) */
        <div className="flex items-center gap-2">
          <div className="relative w-10 h-10 flex items-center justify-center bg-red-600 rounded-xl text-white font-black text-xl shadow-lg shadow-red-500/30">
            Z
          </div>
          <div className="flex flex-col leading-none">
            <span className={`font-black tracking-tight ${sizeMap[size].text} text-red-600 dark:text-red-500`}>
              ZAVERO
            </span>
            <span className={`font-extrabold tracking-widest ${sizeMap[size].fast} text-gray-900 dark:text-white uppercase`}>
              FAST
            </span>
          </div>
        </div>
      )}

      {showSubtitle && (
        <span className={`hidden sm:inline-flex rounded-full bg-red-500/10 text-red-600 dark:text-red-400 border border-red-500/20 font-bold tracking-wider uppercase ${sizeMap[size].badge}`}>
          POS SaaS
        </span>
      )}
    </div>
  );

  if (linkTo) {
    return <Link to={linkTo}>{content}</Link>;
  }

  return content;
};
