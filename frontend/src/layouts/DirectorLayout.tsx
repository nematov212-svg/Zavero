import React, { useState, useEffect } from 'react';
import { Outlet, Link, useLocation, useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import {
  LayoutDashboard,
  Store,
  Users,
  UserCheck,
  ShoppingBag,
  BarChart3,
  Settings,
  Bell,
  LogOut,
  Menu,
  X,
  PhoneCall,
  ExternalLink,
  ShieldCheck,
  ChevronRight,
  Wifi,
  WifiOff,
  KeyRound,
  CheckCircle,
} from 'lucide-react';
import { Logo } from '../components/common/Logo';
import { useAuth } from '../hooks/useAuth';
import { useSocket } from '../hooks/useSocket';
import { directorApi } from '../api/directorApi';
import { authApi } from '../api/authApi';
import { NotificationItem, Lead } from '../types';
import { Modal } from '../components/common/Modal';
import { Button } from '../components/common/Button';

export const DirectorLayout: React.FC = () => {
  const { user, logout, isAuthenticated, isLoading } = useAuth();
  const location = useLocation();
  const navigate = useNavigate();
  const { socket, isConnected } = useSocket(true);

  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [notifications, setNotifications] = useState<NotificationItem[]>([]);
  const [notificationsOpen, setNotificationsOpen] = useState(false);
  const [liveToast, setLiveToast] = useState<{ lead: Lead; notification: NotificationItem } | null>(null);

  // Change Password State
  const [isChangePasswordOpen, setIsChangePasswordOpen] = useState(false);
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [passwordError, setPasswordError] = useState<string | null>(null);
  const [passwordSuccess, setPasswordSuccess] = useState<string | null>(null);
  const [isChangingPassword, setIsChangingPassword] = useState(false);

  const handleChangePassword = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!currentPassword || !newPassword) {
      setPasswordError('Iltimos, joriy va yangi parolni kiriting');
      return;
    }
    if (newPassword !== confirmPassword) {
      setPasswordError('Yangi parollar bir-biriga mos kelmadi');
      return;
    }
    if (newPassword.length < 6) {
      setPasswordError('Yangi parol kamida 6 ta belgidan iborat bo\'lishi kerak');
      return;
    }

    setIsChangingPassword(true);
    setPasswordError(null);
    setPasswordSuccess(null);

    try {
      const res = await authApi.changePassword({ currentPassword, newPassword });
      if (res.success) {
        setPasswordSuccess('Parol muvaffaqiyatli yangilandi!');
        setCurrentPassword('');
        setNewPassword('');
        setConfirmPassword('');
        setTimeout(() => {
          setIsChangePasswordOpen(false);
          setPasswordSuccess(null);
        }, 1800);
      }
    } catch (err: any) {
      setPasswordError(err.message || 'Parolni o\'zgartirishda xatolik yuz berdi');
    } finally {
      setIsChangingPassword(false);
    }
  };

  // Redirect if not authenticated
  useEffect(() => {
    if (!isLoading && !isAuthenticated) {
      navigate('/director/login');
    }
  }, [isLoading, isAuthenticated, navigate]);

  // Load initial notifications
  const fetchNotifications = async () => {
    try {
      const res = await directorApi.getNotifications();
      if (res.success && res.data) {
        setNotifications(res.data);
      }
    } catch (err) {
      console.error('Failed to load notifications:', err);
    }
  };

  useEffect(() => {
    if (isAuthenticated) {
      fetchNotifications();
    }
  }, [isAuthenticated]);

  // Socket listener for new lead notifications
  useEffect(() => {
    if (!socket) return;

    socket.on('new_lead', (data: { lead: Lead; notification: NotificationItem }) => {
      // Play a subtle notification chime if supported
      try {
        const audioCtx = new (window.AudioContext || (window as any).webkitAudioContext)();
        const osc = audioCtx.createOscillator();
        const gain = audioCtx.createGain();
        osc.connect(gain);
        gain.connect(audioCtx.destination);
        osc.frequency.setValueAtTime(587.33, audioCtx.currentTime); // D5
        osc.frequency.setValueAtTime(880, audioCtx.currentTime + 0.1); // A5
        gain.gain.setValueAtTime(0.15, audioCtx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.01, audioCtx.currentTime + 0.3);
        osc.start();
        osc.stop(audioCtx.currentTime + 0.3);
      } catch (e) {
        // audio context blocked by browser
      }

      setLiveToast(data);
      setNotifications((prev) => [data.notification, ...prev]);

      // Auto hide live toast after 8 seconds
      setTimeout(() => {
        setLiveToast((current) => (current?.lead.id === data.lead.id ? null : current));
      }, 8000);
    });

    return () => {
      socket.off('new_lead');
    };
  }, [socket]);

  const unreadCount = notifications.filter((n) => !n.isRead).length;

  const navItems = [
    { label: 'Dashboard', path: '/director', icon: <LayoutDashboard className="w-5 h-5" /> },
    { label: 'Cafelar', path: '/director/cafes', icon: <Store className="w-5 h-5" /> },
    { label: 'Mijozlar (Leadlar)', path: '/director/leads', icon: <Users className="w-5 h-5" /> },
    { label: 'Xodimlar', path: '/director/employees', icon: <UserCheck className="w-5 h-5" /> },
    { label: 'Statistika', path: '/director/statistics', icon: <BarChart3 className="w-5 h-5" /> },
  ];

  if (isLoading) {
    return (
      <div className="min-h-screen bg-[#080A10] flex items-center justify-center">
        <div className="w-12 h-12 rounded-full border-2 border-emerald-500 border-t-transparent animate-spin" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#080A10] text-[#F3F4F6] flex">
      {/* Real-time Toast Alert (Section 9 Requirement) */}
      <AnimatePresence>
        {liveToast && (
          <motion.div
            initial={{ opacity: 0, y: -50, scale: 0.9 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: -50, scale: 0.9 }}
            className="fixed top-6 right-6 z-50 max-w-md w-full glass-panel bg-[#0E1528] border-2 border-emerald-500 rounded-3xl p-5 shadow-2xl shadow-emerald-500/20"
          >
            <div className="flex items-start justify-between gap-3 mb-2">
              <div className="flex items-center gap-2 text-emerald-400 font-extrabold text-sm">
                <span className="w-3 h-3 rounded-full bg-emerald-400 animate-ping" />
                <span>🔔 Yangi mijoz</span>
              </div>
              <button
                onClick={() => setLiveToast(null)}
                className="text-gray-400 hover:text-white p-1 rounded-lg"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="space-y-1 mb-4">
              <h4 className="text-base font-bold text-white">{liveToast.lead.name}</h4>
              <p className="text-xs text-emerald-300 font-semibold">{liveToast.lead.businessName} • {liveToast.lead.city}</p>
              <p className="text-xs text-gray-300 mt-1 font-mono">{liveToast.lead.phone}</p>
              <p className="text-xs text-gray-400 italic mt-1">“Yangi mijoz siz bilan bog'lanishni so'radi.”</p>
            </div>

            <div className="flex items-center gap-2">
              <a
                href={`tel:${liveToast.lead.phone}`}
                className="flex-1 py-2 px-3 rounded-xl bg-emerald-500 hover:bg-emerald-400 text-black text-xs font-bold text-center flex items-center justify-center gap-1.5 transition-colors"
              >
                <PhoneCall className="w-3.5 h-3.5" />
                Qo'ng'iroq qilish
              </a>
              <Link
                to="/director/leads"
                onClick={() => setLiveToast(null)}
                className="py-2 px-3 rounded-xl bg-white/[0.08] hover:bg-white/[0.12] text-white text-xs font-semibold text-center transition-colors"
              >
                Ko'rish
              </Link>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Sidebar Desktop */}
      <aside className="hidden lg:flex flex-col w-64 bg-[#0A0D18] border-r border-white/[0.08] select-none">
        {/* Brand */}
        <div className="p-6 border-b border-white/[0.08]">
          <Logo size="md" linkTo="/director" />
          <span className="text-[11px] text-gray-400 block mt-2 font-mono">Director Control Plane</span>
        </div>

        {/* Navigation */}
        <nav className="flex-1 px-4 py-6 space-y-1.5 overflow-y-auto">
          {navItems.map((item) => {
            const isActive = location.pathname === item.path;
            return (
              <Link
                key={item.path}
                to={item.path}
                className={`flex items-center gap-3 px-4 py-3 rounded-2xl text-sm font-semibold transition-all ${
                  isActive
                    ? 'bg-emerald-500/15 text-emerald-400 border border-emerald-500/30 shadow-md shadow-emerald-500/10'
                    : 'text-gray-400 hover:text-white hover:bg-white/[0.05]'
                }`}
              >
                {item.icon}
                <span>{item.label}</span>
              </Link>
            );
          })}
        </nav>

        {/* Public Website Preview Link */}
        <div className="p-4 border-t border-white/[0.08] space-y-3">
          <Link
            to="/"
            target="_blank"
            className="flex items-center justify-between px-3.5 py-2.5 rounded-xl bg-white/[0.03] hover:bg-white/[0.08] text-xs text-gray-400 hover:text-white border border-white/5 transition-all"
          >
            <span>Web saytni ko'rish</span>
            <ExternalLink className="w-3.5 h-3.5" />
          </Link>

          {/* User profile & Logout */}
          <div className="flex items-center justify-between pt-2">
            <div className="flex items-center gap-2.5 min-w-0">
              <div className="w-9 h-9 rounded-xl bg-emerald-500/15 border border-emerald-500/30 flex items-center justify-center font-bold text-emerald-400 text-xs shrink-0">
                ZB
              </div>
              <div className="truncate">
                <div className="text-xs font-bold text-white truncate">{user?.name || 'Director'}</div>
                <div className="text-[10px] text-emerald-400 font-medium">Boshqaruvchi</div>
              </div>
            </div>

            <div className="flex items-center gap-1">
              <button
                onClick={() => setIsChangePasswordOpen(true)}
                title="Parolni o'zgartirish"
                className="p-2 rounded-xl text-gray-400 hover:text-white hover:bg-white/10 transition-colors cursor-pointer"
              >
                <KeyRound className="w-4 h-4 text-amber-400" />
              </button>

              <button
                onClick={logout}
                title="Chiqish"
                className="p-2 rounded-xl text-gray-400 hover:text-red-400 hover:bg-red-500/10 transition-colors cursor-pointer"
              >
                <LogOut className="w-4 h-4" />
              </button>
            </div>
          </div>
        </div>
      </aside>

      {/* Main Content Area */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Top Header */}
        <header className="h-16 px-4 sm:px-8 border-b border-white/[0.08] bg-[#0A0D18]/80 backdrop-blur-xl flex items-center justify-between sticky top-0 z-30">
          <div className="flex items-center gap-3">
            <button
              onClick={() => setSidebarOpen(!sidebarOpen)}
              className="lg:hidden p-2 rounded-xl text-gray-400 hover:text-white bg-white/[0.05]"
            >
              <Menu className="w-5 h-5" />
            </button>
            <div className="hidden sm:flex items-center gap-2 text-xs font-mono text-gray-400">
              <ShieldCheck className="w-4 h-4 text-emerald-400" />
              <span>Zavero Central Management Node #1</span>
            </div>
          </div>

          <div className="flex items-center gap-4">
            {/* Real-time connection badge */}
            <div
              className={`flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-mono border ${
                isConnected
                  ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30'
                  : 'bg-amber-500/10 text-amber-400 border-amber-500/30'
              }`}
            >
              {isConnected ? (
                <>
                  <Wifi className="w-3.5 h-3.5" />
                  <span className="hidden sm:inline">WebSocket: Real-time</span>
                </>
              ) : (
                <>
                  <WifiOff className="w-3.5 h-3.5" />
                  <span className="hidden sm:inline">Ulanmoqda...</span>
                </>
              )}
            </div>

            {/* Notifications Dropdown */}
            <div className="relative">
              <button
                onClick={() => setNotificationsOpen(!notificationsOpen)}
                className="relative p-2 rounded-xl text-gray-300 hover:text-white bg-white/[0.05] border border-white/10 cursor-pointer"
              >
                <Bell className="w-5 h-5" />
                {unreadCount > 0 && (
                  <span className="absolute -top-1 -right-1 w-5 h-5 rounded-full bg-red-500 text-white text-[10px] font-bold flex items-center justify-center animate-pulse">
                    {unreadCount}
                  </span>
                )}
              </button>

              {notificationsOpen && (
                <div className="absolute right-0 mt-3 w-80 sm:w-96 glass-panel bg-[#0E1322] border border-white/10 rounded-2xl shadow-2xl p-4 z-40">
                  <div className="flex items-center justify-between pb-3 border-b border-white/10 mb-3">
                    <h4 className="text-sm font-bold text-white">Bildirishnomalar</h4>
                    <span className="text-xs text-emerald-400 font-semibold">{unreadCount} ta yangi</span>
                  </div>

                  <div className="max-h-72 overflow-y-auto space-y-2">
                    {notifications.length === 0 ? (
                      <p className="text-xs text-gray-400 text-center py-4">Bildirishnomalar yo'q</p>
                    ) : (
                      notifications.slice(0, 10).map((n) => (
                        <div
                          key={n.id}
                          className="p-3 rounded-xl bg-white/[0.03] border border-white/5 hover:border-emerald-500/30 transition-all text-xs"
                        >
                          <div className="font-bold text-white mb-0.5">{n.title}</div>
                          <p className="text-gray-300 line-clamp-2">{n.message}</p>
                          <span className="text-[10px] text-gray-400 mt-1 block">
                            {new Date(n.createdAt).toLocaleTimeString('uz-UZ')}
                          </span>
                        </div>
                      ))
                    )}
                  </div>
                </div>
              )}
            </div>
          </div>
        </header>

        {/* Page Content */}
        <main className="flex-1 p-4 sm:p-8 overflow-y-auto">
          <Outlet />
        </main>
      </div>

      {/* Mobile Sidebar Drawer */}
      {sidebarOpen && (
        <div className="lg:hidden fixed inset-0 z-50 flex">
          <div
            className="fixed inset-0 bg-black/80 backdrop-blur-sm"
            onClick={() => setSidebarOpen(false)}
          />
          <aside className="relative w-72 bg-[#0A0D18] border-r border-white/10 p-6 flex flex-col justify-between z-10">
            <div>
              <div className="flex items-center justify-between pb-6 border-b border-white/10">
                <Logo size="md" linkTo="/director" />
                <button
                  onClick={() => setSidebarOpen(false)}
                  className="p-1 rounded-lg text-gray-400 hover:text-white"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              <nav className="mt-6 space-y-2">
                {navItems.map((item) => {
                  const isActive = location.pathname === item.path;
                  return (
                    <Link
                      key={item.path}
                      to={item.path}
                      onClick={() => setSidebarOpen(false)}
                      className={`flex items-center gap-3 px-4 py-3 rounded-2xl text-sm font-semibold transition-all ${
                        isActive
                          ? 'bg-emerald-500/15 text-emerald-400 border border-emerald-500/30'
                          : 'text-gray-400 hover:text-white'
                      }`}
                    >
                      {item.icon}
                      <span>{item.label}</span>
                    </Link>
                  );
                })}
              </nav>
            </div>

            <button
              onClick={logout}
              className="w-full py-3 rounded-xl bg-red-500/10 text-red-400 border border-red-500/20 text-xs font-bold flex items-center justify-center gap-2"
            >
              <LogOut className="w-4 h-4" />
              Tizimdan chiqish
            </button>
          </aside>
        </div>
      )}

      {/* Change Password Modal */}
      <Modal
        isOpen={isChangePasswordOpen}
        onClose={() => setIsChangePasswordOpen(false)}
        title="Director Parolini O'zgartirish"
      >
        <form onSubmit={handleChangePassword} className="space-y-4">
          <p className="text-xs text-gray-300">
            Director parolini faqat o'zingiz biladigan maxfiy yangi parolga o'zgartiring. Hech kim bu parolni bilmasligi lozim.
          </p>

          {passwordError && (
            <div className="p-3 rounded-xl bg-red-500/15 border border-red-500/30 text-red-400 text-xs font-medium">
              {passwordError}
            </div>
          )}

          {passwordSuccess && (
            <div className="p-3 rounded-xl bg-emerald-500/15 border border-emerald-500/30 text-emerald-400 text-xs font-medium flex items-center gap-2">
              <CheckCircle className="w-4 h-4 text-emerald-400" />
              <span>{passwordSuccess}</span>
            </div>
          )}

          <div>
            <label className="block text-xs font-semibold text-gray-300 mb-1">Joriy parol</label>
            <input
              type="password"
              placeholder="••••••••••••"
              value={currentPassword}
              onChange={(e) => setCurrentPassword(e.target.value)}
              className="w-full glass-input px-3.5 py-2.5 rounded-xl text-sm font-mono"
              required
            />
          </div>

          <div>
            <label className="block text-xs font-semibold text-gray-300 mb-1">Yangi xavfsiz parol</label>
            <input
              type="password"
              placeholder="Kamida 6 ta belgi"
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
              className="w-full glass-input px-3.5 py-2.5 rounded-xl text-sm font-mono"
              required
            />
          </div>

          <div>
            <label className="block text-xs font-semibold text-gray-300 mb-1">Yangi parolni qayta kiriting</label>
            <input
              type="password"
              placeholder="Takrorlang"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              className="w-full glass-input px-3.5 py-2.5 rounded-xl text-sm font-mono"
              required
            />
          </div>

          <div className="flex items-center justify-end gap-3 pt-3">
            <Button
              type="button"
              variant="ghost"
              size="sm"
              onClick={() => setIsChangePasswordOpen(false)}
            >
              Bekor qilish
            </Button>
            <Button
              type="submit"
              variant="primary"
              size="sm"
              isLoading={isChangingPassword}
            >
              Parolni yangilash
            </Button>
          </div>
        </form>
      </Modal>
    </div>
  );
};
