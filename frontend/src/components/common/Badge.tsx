import React from 'react';

interface BadgeProps {
  status: 'new' | 'contacted' | 'converted' | 'rejected' | 'ACTIVE' | 'INACTIVE' | string;
  className?: string;
}

export const Badge: React.FC<BadgeProps> = ({ status, className = '' }) => {
  const getBadgeConfig = (s: string) => {
    switch (s.toLowerCase()) {
      case 'new':
      case 'yangi':
        return {
          label: 'Yangi',
          style: 'bg-emerald-500/15 text-emerald-400 border-emerald-500/30',
          dot: 'bg-emerald-400 animate-pulse',
        };
      case 'contacted':
      case 'bog\'lanildi':
      case 'boglanildi':
        return {
          label: 'Bog\'lanildi',
          style: 'bg-cyan-500/15 text-cyan-400 border-cyan-500/30',
          dot: 'bg-cyan-400',
        };
      case 'converted':
      case 'hamkor':
      case 'hamkor bo\'ldi':
        return {
          label: 'Mijoz bo\'ldi',
          style: 'bg-indigo-500/15 text-indigo-400 border-indigo-500/30',
          dot: 'bg-indigo-400',
        };
      case 'rejected':
      case 'rad etildi':
      case 'bekor qilindi':
        return {
          label: 'Rad etildi',
          style: 'bg-red-500/15 text-red-400 border-red-500/30',
          dot: 'bg-red-400',
        };
      case 'active':
      case 'faol':
        return {
          label: 'Faol',
          style: 'bg-emerald-500/15 text-emerald-400 border-emerald-500/30',
          dot: 'bg-emerald-400',
        };
      case 'inactive':
      case 'nofaol':
        return {
          label: 'Nofaol',
          style: 'bg-gray-500/15 text-gray-400 border-gray-500/30',
          dot: 'bg-gray-400',
        };
      default:
        return {
          label: s,
          style: 'bg-gray-500/15 text-gray-400 border-gray-500/30',
          dot: 'bg-gray-400',
        };
    }
  };

  const config = getBadgeConfig(status);

  return (
    <span
      className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-medium border ${config.style} ${className}`}
    >
      <span className={`w-1.5 h-1.5 rounded-full ${config.dot}`} />
      <span>{config.label}</span>
    </span>
  );
};
