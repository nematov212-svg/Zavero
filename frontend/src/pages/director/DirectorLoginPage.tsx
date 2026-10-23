import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { motion } from 'framer-motion';
import { Lock, Mail, ArrowRight, ShieldCheck, AlertCircle, Eye, EyeOff, KeyRound } from 'lucide-react';
import { Logo } from '../../components/common/Logo';
import { Button } from '../../components/common/Button';
import { authApi } from '../../api/authApi';
import { useAuth } from '../../hooks/useAuth';

export const DirectorLoginPage: React.FC = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  const { login } = useAuth();
  const navigate = useNavigate();

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email.trim() || !password.trim()) {
      setError('Iltimos, email va xavfsiz parolingizni kiriting');
      return;
    }

    setIsLoading(true);
    setError(null);

    try {
      const response = await authApi.login({ email, password });
      if (response.success && response.data) {
        login(response.data.token, response.data.user);
        navigate('/director');
      }
    } catch (err: any) {
      setError(err.message || 'Kirish taqiqlandi. Email yoki parol noto\'g\'ri.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#07090E] flex flex-col justify-center items-center p-4 sm:p-6 relative overflow-hidden select-none">
      {/* Background ambient lighting */}
      <div className="absolute top-1/4 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[700px] h-[550px] bg-red-600/10 rounded-full blur-[150px] pointer-events-none" />
      <div className="absolute bottom-10 right-10 w-96 h-96 bg-red-500/5 rounded-full blur-[120px] pointer-events-none" />

      {/* Grid overlay */}
      <div className="absolute inset-0 bg-[linear-gradient(to_right,#ffffff05_1px,transparent_1px),linear-gradient(to_bottom,#ffffff05_1px,transparent_1px)] bg-[size:3.5rem_3.5rem] pointer-events-none -z-10" />

      <div className="w-full max-w-md relative z-10">
        {/* Brand & Security Header */}
        <div className="text-center mb-8">
          <div className="inline-block mb-4 hover:scale-105 transition-transform">
            <Logo size="lg" linkTo="/" />
          </div>

          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-red-500/10 border border-red-500/30 text-red-500 text-xs font-bold mb-3 shadow-sm">
            <ShieldCheck className="w-3.5 h-3.5" />
            <span>Himoyalangan Boshqaruv Qatlami</span>
          </div>

          <h2 className="text-2xl sm:text-3xl font-black text-white tracking-tight">
            Director Kirish Markazi
          </h2>
          <p className="text-xs text-gray-400 mt-1 max-w-xs mx-auto">
            Faqat tizim rahbari va vakolatli boshqaruvchilar uchun yopiq hudud
          </p>
        </div>

        {/* Security Card */}
        <motion.div
          initial={{ opacity: 0, y: 25 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.4 }}
          className="glass-panel p-8 sm:p-9 rounded-3xl border border-white/10 bg-[#0D111E]/95 shadow-2xl relative overflow-hidden"
        >
          {/* Top glowing line */}
          <div className="absolute top-0 left-0 right-0 h-[2px] bg-gradient-to-r from-transparent via-red-500 to-transparent" />

          {error && (
            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              className="mb-6 p-4 rounded-2xl bg-red-500/15 border border-red-500/40 flex items-start gap-3 text-red-400 text-xs"
            >
              <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
              <div className="font-medium leading-relaxed">{error}</div>
            </motion.div>
          )}

          <form onSubmit={handleLogin} className="space-y-5">
            <div>
              <label className="block text-xs font-bold text-gray-300 mb-2">
                Director Email manzili
              </label>
              <div className="relative">
                <Mail className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                <input
                  type="email"
                  placeholder="director@zavero.uz"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="w-full glass-input pl-10 pr-4 py-3 rounded-xl text-sm font-medium"
                  autoComplete="username"
                  required
                />
              </div>
            </div>

            <div>
              <div className="flex items-center justify-between mb-2">
                <label className="block text-xs font-bold text-gray-300">
                  Xavfsiz parol
                </label>
                <span className="text-[11px] text-gray-500 font-mono">End-to-End Encrypted</span>
              </div>
              <div className="relative">
                <Lock className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                <input
                  type={showPassword ? 'text' : 'password'}
                  placeholder="••••••••••••"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="w-full glass-input pl-10 pr-11 py-3 rounded-xl text-sm font-mono tracking-wider"
                  autoComplete="current-password"
                  required
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3.5 top-1/2 -translate-y-1/2 text-gray-400 hover:text-white transition-colors cursor-pointer"
                  tabIndex={-1}
                >
                  {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
            </div>

            <Button
              type="submit"
              variant="primary"
              size="lg"
              isLoading={isLoading}
              rightIcon={<ArrowRight className="w-4 h-4" />}
              className="w-full justify-center py-4 text-sm font-bold mt-3 bg-red-600 hover:bg-red-500 shadow-red-600/30"
            >
              Tizimga xavfsiz kirish
            </Button>
          </form>

          {/* Security Assurance Footer */}
          <div className="mt-6 pt-5 border-t border-white/[0.08] flex items-center justify-between text-[11px] text-gray-500 font-mono">
            <span className="flex items-center gap-1.5 text-emerald-400">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
              SSL 256-Bit Himoyalangan
            </span>
            <span>Brute-force Filter Active</span>
          </div>
        </motion.div>

        {/* Back to site */}
        <div className="text-center mt-6">
          <Link to="/" className="text-xs text-gray-400 hover:text-white transition-colors">
            ← Asosiy web saytga qaytish
          </Link>
        </div>
      </div>
    </div>
  );
};
