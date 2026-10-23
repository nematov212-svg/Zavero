import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import {
  Store,
  Key,
  Copy,
  Check,
  Edit,
  Trash2,
  MapPin,
  Phone,
  User,
  Layers,
  Sparkles,
  RefreshCw,
  Smartphone,
  Info,
  ShieldCheck,
  CheckCircle2,
} from 'lucide-react';
import { directorApi } from '../../api/directorApi';
import { Cafe } from '../../types';
import { Badge } from '../../components/common/Badge';
import { Button } from '../../components/common/Button';
import { Modal } from '../../components/common/Modal';
import { useSocket } from '../../hooks/useSocket';

export const DirectorCafesPage: React.FC = () => {
  const [cafes, setCafes] = useState<Cafe[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [copiedKey, setCopiedKey] = useState<string | null>(null);
  const { socket } = useSocket(true);

  // Edit Modal State
  const [editingCafe, setEditingCafe] = useState<Cafe | null>(null);
  const [editFormData, setEditFormData] = useState({
    name: '',
    ownerName: '',
    phone: '',
    city: '',
    address: '',
    activeTables: 12,
    status: 'ACTIVE' as 'ACTIVE' | 'INACTIVE',
  });
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [editError, setEditError] = useState<string | null>(null);

  const fetchCafes = async () => {
    try {
      setIsLoading(true);
      const res = await directorApi.getCafes();
      if (res.success && res.data) {
        setCafes(res.data);
      }
    } catch (err) {
      console.error('Failed to load cafes:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchCafes();
  }, []);

  // Real-time synchronization
  useEffect(() => {
    if (!socket) return;
    socket.on('cafe_updated', () => fetchCafes());
    socket.on('stats_updated', () => fetchCafes());

    return () => {
      socket.off('cafe_updated');
      socket.off('stats_updated');
    };
  }, [socket]);

  const handleCopyKey = (key: string) => {
    navigator.clipboard.writeText(key);
    setCopiedKey(key);
    setTimeout(() => setCopiedKey(null), 2500);
  };

  const handleOpenEditModal = (cafe: Cafe) => {
    setEditingCafe(cafe);
    setEditFormData({
      name: cafe.name,
      ownerName: cafe.ownerName,
      phone: cafe.phone,
      city: cafe.city,
      address: cafe.address,
      activeTables: cafe.activeTables,
      status: cafe.status,
    });
    setEditError(null);
  };

  const handleSaveEdit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingCafe) return;

    setIsSubmitting(true);
    setEditError(null);

    try {
      const res = await directorApi.updateCafe(editingCafe.id, editFormData);
      if (res.success) {
        setEditingCafe(null);
        fetchCafes();
      }
    } catch (err: any) {
      setEditError(err.message || 'Xatolik yuz berdi');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleRegenerateKey = async (id: string) => {
    if (!window.confirm('Haqiqatan ham ushbu cafe uchun yangi API Key yaratmoqchimisiz? Eski kalit bekor bo\'ladi.')) return;
    try {
      await directorApi.regenerateApiKey(id);
      fetchCafes();
    } catch (err) {
      console.error('Failed to regenerate key:', err);
    }
  };

  const handleDeleteCafe = async (id: string, name: string) => {
    if (!window.confirm(`"${name}" cafesini tizimdan o'chirmoqchimisiz?`)) return;
    try {
      await directorApi.deleteCafe(id);
      fetchCafes();
    } catch (err) {
      console.error('Failed to delete cafe:', err);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl sm:text-3xl font-extrabold text-white tracking-tight flex items-center gap-3">
            <span>Cafelar va Filiallar</span>
            <span className="text-xs px-2.5 py-1 rounded-full bg-red-500/10 text-red-400 border border-red-500/20 font-mono">
              {cafes.length} ta faoliyatda
            </span>
          </h1>
          <p className="text-xs sm:text-sm text-gray-400 mt-1">
            Zavero Flutter ilovasi orqali ulangan cafe va restoranlar monitoringi
          </p>
        </div>

        <button
          onClick={fetchCafes}
          className="p-2.5 rounded-xl text-gray-400 hover:text-white bg-white/[0.05] border border-white/10 transition-colors self-start sm:self-auto cursor-pointer flex items-center gap-2 text-xs"
        >
          <RefreshCw className="w-4 h-4 text-red-500" />
          <span>Yangilash</span>
        </button>
      </div>

      {/* Integration Info Banner */}
      <div className="glass-panel p-5 sm:p-6 rounded-3xl border border-red-500/30 bg-gradient-to-r from-red-500/10 via-transparent to-transparent">
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <div className="flex items-start gap-3.5">
            <div className="w-10 h-10 rounded-2xl bg-red-500/20 border border-red-500/40 flex items-center justify-center text-red-500 shrink-0">
              <Smartphone className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-sm font-bold text-white flex items-center gap-2">
                <span>Zavero Flutter Ilovasi Integratsiyasi</span>
                <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-500/15 text-emerald-400 border border-emerald-500/30">
                  Avtomatik Sinxronizatsiya
                </span>
              </h3>
              <p className="text-xs text-gray-300 mt-1 max-w-2xl leading-relaxed">
                Yangi cafelar web sayt orqali qo'lda kiritilmaydi. Ular Zavero Flutter ilovasidan ro'yxatdan o'tganda (<code className="text-red-400 bg-black/30 px-1.5 py-0.5 rounded">POST /api/cafes</code>) avtomatik tarzda bu yerga va web saytga qo'shiladi hamda buyurtmalar real vaqtda hisoblanadi.
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Cafes Cards Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {isLoading ? (
          [1, 2, 3].map((i) => (
            <div key={i} className="h-64 rounded-3xl bg-[#131A2E]/50 border border-white/10 animate-shimmer" />
          ))
        ) : cafes.length === 0 ? (
          <div className="col-span-full glass-panel p-16 rounded-3xl text-center text-gray-400">
            <Store className="w-12 h-12 mx-auto mb-3 opacity-30 text-red-500" />
            <p className="text-base font-bold text-white">Hozircha cafelar ulanmagan</p>
            <p className="text-xs text-gray-400 mt-1">Zavero Flutter ilovasi orqali birinchi cafe ro'yxatdan o'tishi kutilmoqda</p>
          </div>
        ) : (
          cafes.map((cafe) => (
            <motion.div
              key={cafe.id}
              initial={{ opacity: 0, y: 15 }}
              animate={{ opacity: 1, y: 0 }}
              className="glass-card p-6 rounded-3xl border border-white/10 hover:border-red-500/40 relative flex flex-col justify-between group"
            >
              <div>
                <div className="flex items-center justify-between mb-4">
                  <div className="w-11 h-11 rounded-2xl bg-red-500/10 border border-red-500/30 flex items-center justify-center text-red-500 font-bold">
                    <Store className="w-5 h-5" />
                  </div>
                  <Badge status={cafe.status} />
                </div>

                <h3 className="text-lg font-bold text-white mb-1 group-hover:text-red-500 transition-colors">
                  {cafe.name}
                </h3>
                <p className="text-xs text-gray-400 mb-4">{cafe.city}, {cafe.address}</p>

                <div className="space-y-2 text-xs text-gray-300 pt-2 border-t border-white/[0.06] mb-4">
                  <div className="flex items-center justify-between">
                    <span className="text-gray-400 flex items-center gap-1.5">
                      <User className="w-3.5 h-3.5" /> Egasi:
                    </span>
                    <span className="font-semibold text-white">{cafe.ownerName}</span>
                  </div>

                  <div className="flex items-center justify-between">
                    <span className="text-gray-400 flex items-center gap-1.5">
                      <Phone className="w-3.5 h-3.5" /> Telefon:
                    </span>
                    <a href={`tel:${cafe.phone}`} className="font-mono text-red-400 hover:underline">
                      {cafe.phone}
                    </a>
                  </div>

                  <div className="flex items-center justify-between">
                    <span className="text-gray-400 flex items-center gap-1.5">
                      <Layers className="w-3.5 h-3.5" /> Stollar:
                    </span>
                    <span className="font-bold text-white">{cafe.activeTables} ta stol</span>
                  </div>
                </div>

                {/* Flutter API Key Section */}
                <div className="p-3 rounded-2xl bg-black/40 border border-white/[0.06] mb-4">
                  <div className="flex items-center justify-between mb-1">
                    <span className="text-[10px] uppercase font-bold text-gray-400 flex items-center gap-1">
                      <Key className="w-3 h-3 text-cyan-400" /> Flutter POS API Key:
                    </span>
                    <button
                      onClick={() => handleCopyKey(cafe.apiKey)}
                      className="text-[11px] text-cyan-400 hover:text-cyan-300 flex items-center gap-1 font-semibold cursor-pointer"
                    >
                      {copiedKey === cafe.apiKey ? (
                        <>
                          <Check className="w-3 h-3 text-emerald-400" /> Nusxalandi!
                        </>
                      ) : (
                        <>
                          <Copy className="w-3 h-3" /> Nusxalash
                        </>
                      )}
                    </button>
                  </div>
                  <div className="font-mono text-[11px] text-gray-300 truncate select-all">
                    {cafe.apiKey}
                  </div>
                </div>
              </div>

              {/* Bottom Actions */}
              <div className="pt-3 border-t border-white/[0.08] flex items-center justify-between text-xs">
                <span className="text-[11px] text-gray-400">
                  Ulandi: {new Date(cafe.createdAt).toLocaleDateString('uz-UZ')}
                </span>

                <div className="flex items-center gap-1.5">
                  <button
                    onClick={() => handleRegenerateKey(cafe.id)}
                    className="p-1.5 rounded-lg text-gray-400 hover:text-cyan-400 hover:bg-cyan-500/10 transition-colors cursor-pointer"
                    title="Yangi API Key yaratish"
                  >
                    <Key className="w-4 h-4" />
                  </button>

                  <button
                    onClick={() => handleOpenEditModal(cafe)}
                    className="p-1.5 rounded-lg text-gray-400 hover:text-white hover:bg-white/10 transition-colors cursor-pointer"
                    title="Tahrirlash"
                  >
                    <Edit className="w-4 h-4" />
                  </button>

                  <button
                    onClick={() => handleDeleteCafe(cafe.id, cafe.name)}
                    className="p-1.5 rounded-lg text-gray-400 hover:text-red-400 hover:bg-red-500/10 transition-colors cursor-pointer"
                    title="O'chirish"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </div>
            </motion.div>
          ))
        )}
      </div>

      {/* Edit Cafe Modal */}
      <Modal
        isOpen={!!editingCafe}
        onClose={() => setEditingCafe(null)}
        title="Cafe ma'lumotlarini tahrirlash"
      >
        {editingCafe && (
          <form onSubmit={handleSaveEdit} className="space-y-4">
            {editError && (
              <div className="p-3 rounded-xl bg-red-500/10 border border-red-500/30 text-red-400 text-xs">
                {editError}
              </div>
            )}

            <div>
              <label className="block text-xs font-semibold text-gray-300 mb-1">Cafe nomi</label>
              <input
                type="text"
                value={editFormData.name}
                onChange={(e) => setEditFormData({ ...editFormData, name: e.target.value })}
                className="w-full glass-input px-3.5 py-2.5 rounded-xl text-sm"
                required
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-semibold text-gray-300 mb-1">Egasi</label>
                <input
                  type="text"
                  value={editFormData.ownerName}
                  onChange={(e) => setEditFormData({ ...editFormData, ownerName: e.target.value })}
                  className="w-full glass-input px-3.5 py-2.5 rounded-xl text-sm"
                  required
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-gray-300 mb-1">Telefon</label>
                <input
                  type="text"
                  value={editFormData.phone}
                  onChange={(e) => setEditFormData({ ...editFormData, phone: e.target.value })}
                  className="w-full glass-input px-3.5 py-2.5 rounded-xl text-sm font-mono"
                  required
                />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-semibold text-gray-300 mb-1">Shahar</label>
                <input
                  type="text"
                  value={editFormData.city}
                  onChange={(e) => setEditFormData({ ...editFormData, city: e.target.value })}
                  className="w-full glass-input px-3.5 py-2.5 rounded-xl text-sm"
                  required
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-gray-300 mb-1">Stollar soni</label>
                <input
                  type="number"
                  min={1}
                  value={editFormData.activeTables}
                  onChange={(e) => setEditFormData({ ...editFormData, activeTables: parseInt(e.target.value) || 1 })}
                  className="w-full glass-input px-3.5 py-2.5 rounded-xl text-sm"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-semibold text-gray-300 mb-1">Manzil</label>
              <input
                type="text"
                value={editFormData.address}
                onChange={(e) => setEditFormData({ ...editFormData, address: e.target.value })}
                className="w-full glass-input px-3.5 py-2.5 rounded-xl text-sm"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold text-gray-300 mb-1">Status</label>
              <select
                value={editFormData.status}
                onChange={(e) => setEditFormData({ ...editFormData, status: e.target.value as any })}
                className="w-full glass-input px-3.5 py-2.5 rounded-xl text-sm bg-[#0A0D18]"
              >
                <option value="ACTIVE">Faol (Active)</option>
                <option value="INACTIVE">Nofaol (Inactive)</option>
              </select>
            </div>

            <div className="flex items-center justify-end gap-3 pt-3">
              <Button
                type="button"
                variant="ghost"
                size="sm"
                onClick={() => setEditingCafe(null)}
              >
                Bekor qilish
              </Button>
              <Button
                type="submit"
                variant="primary"
                size="sm"
                isLoading={isSubmitting}
              >
                Saqlash
              </Button>
            </div>
          </form>
        )}
      </Modal>
    </div>
  );
};
