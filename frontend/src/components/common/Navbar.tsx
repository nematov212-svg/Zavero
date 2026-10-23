import React, { useState, useEffect } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { Menu, X, ArrowRight, Sparkles, Sun, Moon, Volume2, VolumeX, PhoneCall } from 'lucide-react';
import { Logo } from './Logo';
import { Button } from './Button';
import { useTheme } from '../../hooks/useTheme';
import { useMusic } from '../../hooks/useMusic';

export const Navbar: React.FC = () => {
  const [isScrolled, setIsScrolled] = useState(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const { theme, toggleTheme } = useTheme();
  const { isPlaying, toggleMusic } = useMusic();
  const location = useLocation();

  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 20);
    };
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  useEffect(() => {
    setMobileMenuOpen(false);
  }, [location.pathname]);

  const navLinks = [
    { label: 'Asosiy', path: '/' },
    { label: 'Imkoniyatlar', path: '/features' },
    { label: 'Tariflar', path: '/pricing' },
    { label: 'Biz haqimizda', path: '/about' },
    { label: 'Bog\'lanish', path: '/contact' },
  ];

  return (
    <header
      className={`fixed top-0 left-0 right-0 z-40 transition-all duration-300 ${isScrolled
        ? 'py-3.5 bg-white/95 dark:bg-[#080A10]/95 backdrop-blur-xl border-b border-gray-200 dark:border-white/[0.08] shadow-md dark:shadow-2xl'
        : 'py-5 bg-transparent'
        }`}
    >
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between">
          {/* Logo */}
          <Logo size="md" />

          {/* Desktop Navigation Links */}
          <nav className="hidden md:flex items-center gap-1 glass-panel px-4 py-1.5 rounded-full border border-gray-200 dark:border-white/[0.08] bg-white/80 dark:bg-[#0E1322]/80 shadow-sm">
            {navLinks.map((link) => {
              const isActive = location.pathname === link.path;
              return (
                <Link
                  key={link.path}
                  to={link.path}
                  className={`px-4 py-1.5 rounded-full text-xs font-bold tracking-wide transition-all duration-200 ${isActive
                    ? 'bg-red-500/15 text-red-600 dark:text-red-400 border border-red-500/30'
                    : 'text-gray-700 dark:text-gray-300 hover:text-red-600 dark:hover:text-white hover:bg-gray-100 dark:hover:bg-white/[0.06]'
                    }`}
                >
                  {link.label}
                </Link>
              );
            })}
          </nav>

          {/* Action Buttons: Music Player, Theme Switcher & Contact */}
          <div className="hidden md:flex items-center gap-2.5">
            {/* Musiqa Yoqish / O'chirish Tugmasi */}
            <button
              onClick={toggleMusic}
              title={isPlaying ? "Musiqani to'xtatish" : "Musiqani yoqish (Ambient Lounge)"}
              className={`px-3 py-2 rounded-xl border flex items-center gap-2 text-xs font-bold transition-all cursor-pointer shadow-sm hover:scale-105 ${isPlaying
                ? 'bg-red-500/15 border-red-500/40 text-red-600 dark:text-red-400 shadow-red-500/20'
                : 'bg-white dark:bg-white/[0.05] border-gray-200 dark:border-white/10 text-gray-700 dark:text-gray-300 hover:text-red-600 dark:hover:text-white'
                }`}
            >
              {isPlaying ? (
                <>
                  <div className="flex items-end gap-0.5 h-3.5 w-3.5">
                    <span className="w-1 bg-red-500 rounded-full animate-pulse" style={{ height: '100%' }} />
                    <span className="w-1 bg-red-500 rounded-full animate-pulse" style={{ height: '60%', animationDelay: '0.2s' }} />
                    <span className="w-1 bg-red-500 rounded-full animate-pulse" style={{ height: '85%', animationDelay: '0.4s' }} />
                  </div>
                  <span className="text-[11px]">Musiqa: Yoqilgan</span>
                </>
              ) : (
                <>
                  <VolumeX className="w-4 h-4 text-gray-400" />
                  <span className="text-[11px]">Musiqani yoqish 🎵</span>
                </>
              )}
            </button>

            {/* Kun / Tun (Theme Switcher) */}
            <button
              onClick={toggleTheme}
              title={theme === 'dark' ? "Kunduzgi rejim (Oq fon)" : "Tungi rejim (Qorong'i fon)"}
              className="p-2.5 rounded-xl border border-gray-200 dark:border-white/10 bg-white dark:bg-white/[0.05] text-gray-700 dark:text-gray-300 hover:text-red-600 dark:hover:text-amber-400 transition-all cursor-pointer shadow-sm hover:scale-105 flex items-center gap-1.5"
            >
              {theme === 'dark' ? (
                <>
                  <Sun className="w-4 h-4 text-amber-400" />
                  <span className="text-[11px] font-bold text-gray-300 hidden lg:inline">Kunduzgi</span>
                </>
              ) : (
                <>
                  <Moon className="w-4 h-4 text-indigo-600" />
                  <span className="text-[11px] font-bold text-gray-700 hidden lg:inline">Tungi</span>
                </>
              )}
            </button>

            <a
              href="tel:+998507230475"
              className="hidden lg:inline-flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-bold text-gray-700 dark:text-gray-300 border border-gray-200 dark:border-white/10 hover:border-red-500/40 hover:text-red-600 transition-colors"
            >
              <PhoneCall className="w-3.5 h-3.5 text-red-500" />
              <span className="font-mono">+998 (50) 723-04-75</span>
            </a>

            <Link to="/contact">
              <Button
                variant="primary"
                size="sm"
                rightIcon={<ArrowRight className="w-3.5 h-3.5" />}
                className="font-bold shadow-md shadow-red-500/20"
              >
                Bog'lanish
              </Button>
            </Link>
          </div>

          {/* Mobile Right Controls */}
          <div className="flex md:hidden items-center gap-2">
            {/* Mobile Music Toggle */}
            <button
              onClick={toggleMusic}
              className={`p-2 rounded-xl border transition-colors ${isPlaying
                ? 'bg-red-500/20 border-red-500/40 text-red-600'
                : 'bg-white dark:bg-white/[0.05] border-gray-200 dark:border-white/10 text-gray-600 dark:text-gray-300'
                }`}
              title="Musiqa"
            >
              {isPlaying ? <Volume2 className="w-5 h-5 text-red-600 animate-pulse" /> : <VolumeX className="w-5 h-5" />}
            </button>

            {/* Mobile Theme Toggle */}
            <button
              onClick={toggleTheme}
              className="p-2 rounded-xl border border-gray-200 dark:border-white/10 bg-white dark:bg-white/[0.05] text-gray-700 dark:text-gray-300"
              title="Rejim"
            >
              {theme === 'dark' ? <Sun className="w-5 h-5 text-amber-400" /> : <Moon className="w-5 h-5 text-indigo-600" />}
            </button>

            <button
              onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
              className="p-2 rounded-xl text-gray-800 dark:text-gray-200 bg-white dark:bg-white/[0.05] border border-gray-200 dark:border-white/10 focus:outline-none"
              aria-label="Toggle menu"
            >
              {mobileMenuOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
            </button>
          </div>
        </div>
      </div>

      {/* Mobile Animated Dropdown Menu */}
      {mobileMenuOpen && (
        <div className="md:hidden glass-panel border-b border-gray-200 dark:border-white/10 bg-white/98 dark:bg-[#080A10]/98 backdrop-blur-2xl mt-3 px-6 py-6 transition-all duration-300 shadow-2xl">
          <div className="flex flex-col gap-2">
            {navLinks.map((link) => {
              const isActive = location.pathname === link.path;
              return (
                <Link
                  key={link.path}
                  to={link.path}
                  className={`px-4 py-3 rounded-xl text-sm font-bold transition-all ${isActive
                    ? 'bg-red-500/15 text-red-600 dark:text-red-400 border border-red-500/20'
                    : 'text-gray-800 dark:text-gray-200 hover:bg-gray-100 dark:hover:bg-white/[0.05]'
                    }`}
                >
                  {link.label}
                </Link>
              );
            })}

            <div className="pt-4 mt-2 border-t border-gray-200 dark:border-white/10 flex flex-col gap-3">
              <button
                onClick={toggleMusic}
                className={`w-full py-3 px-4 rounded-xl border flex items-center justify-center gap-2 font-bold text-sm ${isPlaying
                  ? 'bg-red-500/15 border-red-500/40 text-red-600'
                  : 'bg-gray-100 dark:bg-white/[0.05] border-gray-200 dark:border-white/10 text-gray-800 dark:text-gray-200'
                  }`}
              >
                {isPlaying ? <Volume2 className="w-5 h-5 text-red-600 animate-pulse" /> : <VolumeX className="w-5 h-5" />}
                <span>{isPlaying ? "Musiqa yoqilgan (O'chirish)" : "Sayt musiqasini yoqish 🎵"}</span>
              </button>

              <a
                href="tel:+998507230475"
                className="w-full"
              >
                <Button variant="secondary" size="md" className="w-full justify-center font-bold">
                  <PhoneCall className="w-4 h-4 text-red-500 mr-2" />
                  +998 (50) 723-04-75
                </Button>
              </a>

              <Link to="/contact" className="w-full">
                <Button variant="primary" size="md" className="w-full justify-center font-bold shadow-lg shadow-red-500/25">
                  Zavero bilan bog'lanish
                </Button>
              </Link>
            </div>
          </div>
        </div>
      )}
    </header>
  );
};
