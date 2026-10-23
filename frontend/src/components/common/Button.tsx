import React from 'react';

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'outline' | 'ghost' | 'danger';
  size?: 'sm' | 'md' | 'lg';
  isLoading?: boolean;
  leftIcon?: React.ReactNode;
  rightIcon?: React.ReactNode;
}

export const Button: React.FC<ButtonProps> = ({
  children,
  variant = 'primary',
  size = 'md',
  isLoading = false,
  leftIcon,
  rightIcon,
  className = '',
  disabled,
  ...props
}) => {
  const baseStyles = 'relative inline-flex items-center justify-center font-medium rounded-xl transition-all duration-200 select-none overflow-hidden active:scale-[0.98] disabled:opacity-50 disabled:pointer-events-none disabled:active:scale-100 cursor-pointer';

  const sizeStyles = {
    sm: 'text-xs px-3.5 py-1.5 gap-1.5',
    md: 'text-sm px-5 py-2.5 gap-2',
    lg: 'text-base px-6 py-3.5 gap-2.5 font-semibold',
  };

  const variantStyles = {
    primary:
      'bg-red-600 hover:bg-red-500 text-white font-bold shadow-lg shadow-red-600/30 hover:shadow-red-600/40 border border-red-500/40',
    secondary:
      'bg-white dark:bg-[#131A2E] text-gray-900 dark:text-white border border-gray-200 dark:border-white/10 hover:border-red-500/40 shadow-sm hover:shadow-md',
    outline:
      'bg-transparent hover:bg-gray-100 dark:hover:bg-white/[0.05] text-gray-800 dark:text-white border border-gray-300 dark:border-white/15 hover:border-red-500',
    ghost:
      'bg-transparent hover:bg-gray-100 dark:hover:bg-white/[0.06] text-gray-600 dark:text-gray-300 hover:text-red-600 dark:hover:text-white',
    danger:
      'bg-red-500/15 hover:bg-red-500/25 text-red-600 dark:text-red-400 border border-red-500/30',
  };

  return (
    <button
      className={`${baseStyles} ${sizeStyles[size]} ${variantStyles[variant]} ${className}`}
      disabled={disabled || isLoading}
      {...props}
    >
      {isLoading ? (
        <>
          <svg className="animate-spin -ml-1 mr-2 h-4 w-4 text-current" fill="none" viewBox="0 0 24 24">
            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z" />
          </svg>
          <span>Kutilmoqda...</span>
        </>
      ) : (
        <>
          {leftIcon && <span className="inline-flex shrink-0">{leftIcon}</span>}
          <span>{children}</span>
          {rightIcon && <span className="inline-flex shrink-0">{rightIcon}</span>}
        </>
      )}
    </button>
  );
};
