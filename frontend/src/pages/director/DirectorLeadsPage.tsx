import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Users,
  Search,
  PhoneCall,
  Eye,
  Edit,
  Trash2,
  Filter,
  CheckCircle2,
  Calendar,
  Building,
  MapPin,
  MessageSquare,
  RefreshCw,
} from 'lucide-react';
import { directorApi } from '../../api/directorApi';
import { Lead } from '../../types';
import { Badge } from '../../components/common/Badge';
import { Button } from '../../components/common/Button';
import { Modal } from '../../components/common/Modal';
import { useSocket } from '../../hooks/useSocket';

export const DirectorLeadsPage: React.FC = () => {
  const [leads, setLeads] = useState<Lead[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [selectedStatus, setSelectedStatus] = useState<string>('all');
  const { socket } = useSocket(true);

  // Modal States
  const [viewLead, setViewLead] = useState<Lead | null>(null);
  const [editStatusLead, setEditStatusLead] = useState<Lead | null>(null);
  const [newStatus, setNewStatus] = useState<'new' | 'contacted' | 'converted' | 'rejected'>('new');
  const [statusNotes, setStatusNotes] = useState('');
  const [isUpdating, setIsUpdating] = useState(false);

  const fetchLeads = async () => {
    try {
      setIsLoading(true);
      const res = await directorApi.getLeads({
        status: selectedStatus,
        search: search.trim() || undefined,
      });
      if (res.success && res.leads) {
        setLeads(res.leads);
      }
    } catch (err) {
      console.error('Failed to load leads:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchLeads();
  }, [selectedStatus]);

  // Handle search with debouncing or enter
  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    fetchLeads();
  };

  // Socket listeners for real-time lead updates
  useEffect(() => {
    if (!socket) return;

    socket.on('new_lead', (data: { lead: Lead }) => {
      setLeads((prev) => [data.lead, ...prev.filter((l) => l.id !== data.lead.id)]);
    });

    socket.on('lead_status_updated', (updated: Lead) => {
      setLeads((prev) => prev.map((l) => (l.id === updated.id ? updated : l)));
    });

    return () => {
      socket.off('new_lead');
      socket.off('lead_status_updated');
    };
  }, [socket]);

  // Handle Status Update
  const handleUpdateStatus = async () => {
    if (!editStatusLead) return;
    setIsUpdating(true);
    try {
      const res = await directorApi.updateLeadStatus(editStatusLead.id, {
        status: newStatus,
        notes: statusNotes,
      });
      if (res.success && res.data) {
        setLeads((prev) => prev.map((l) => (l.id === res.data.id ? res.data : l)));
        setEditStatusLead(null);
      }
    } catch (err) {
      console.error('Failed to update status:', err);
    } finally {
      setIsUpdating(false);
    }
  };

  // Handle Delete
  const handleDeleteLead = async (id: string) => {
    if (!window.confirm('Haqiqatan ham bu arizani o\'chirmoqchimisiz?')) return;
    try {
      await directorApi.deleteLead(id);
      setLeads((prev) => prev.filter((l) => l.id !== id));
    } catch (err) {
      console.error('Failed to delete lead:', err);
    }
  };

  const statusFilterTabs = [
    { key: 'all', label: 'Barchasi' },
    { key: 'new', label: 'Yangi' },
    { key: 'contacted', label: 'Bog\'lanildi' },
    { key: 'converted', label: 'Mijoz bo\'ldi' },
    { key: 'rejected', label: 'Rad etildi' },
  ];

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl sm:text-3xl font-extrabold text-white tracking-tight flex items-center gap-3">
            <span>Mijozlar (Leadlar)</span>
            <span className="text-xs px-2.5 py-1 rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-mono">
              {leads.length} ta ariza
            </span>
          </h1>
          <p className="text-xs sm:text-sm text-gray-400 mt-1">
            Web saytdan kelgan barcha qiziqqan cafe va restoran egalari ro'yxati
          </p>
        </div>

        <button
          onClick={fetchLeads}
          className="p-2.5 rounded-xl text-gray-400 hover:text-white bg-white/[0.05] border border-white/10 transition-colors self-start sm:self-auto cursor-pointer flex items-center gap-2 text-xs"
        >
          <RefreshCw className="w-4 h-4 text-emerald-400" />
          <span>Yangilash</span>
        </button>
      </div>

      {/* Filter and Search Bar */}
      <div className="glass-panel p-4 rounded-2xl border border-white/10 bg-[#0E1322] flex flex-col md:flex-row items-center justify-between gap-4">
        {/* Status Tabs */}
        <div className="flex items-center gap-1.5 overflow-x-auto w-full md:w-auto pb-2 md:pb-0 scrollbar-none">
          {statusFilterTabs.map((tab) => {
            const isActive = selectedStatus === tab.key;
            return (
              <button
                key={tab.key}
                onClick={() => setSelectedStatus(tab.key)}
                className={`px-3.5 py-2 rounded-xl text-xs font-semibold whitespace-nowrap transition-all cursor-pointer ${
                  isActive
                    ? 'bg-emerald-500 text-black font-bold shadow-md shadow-emerald-500/20'
                    : 'text-gray-400 hover:text-white hover:bg-white/[0.05]'
                }`}
              >
                {tab.label}
              </button>
            );
          })}
        </div>

        {/* Search Input */}
        <form onSubmit={handleSearchSubmit} className="relative w-full md:w-72">
          <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input
            type="text"
            placeholder="Ism, telefon yoki cafe..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full glass-input pl-10 pr-4 py-2 rounded-xl text-xs"
          />
        </form>
      </div>

      {/* Leads Table */}
      <div className="glass-panel rounded-3xl border border-white/10 bg-[#0E1322] overflow-hidden shadow-2xl">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-[#090C16] border-b border-white/[0.08] text-gray-400 font-semibold uppercase tracking-wider text-[11px]">
              <tr>
                <th className="py-4 px-6">Ism</th>
                <th className="py-4 px-6">Telefon (Qo'ng'iroq)</th>
                <th className="py-4 px-6">Cafe / Restoran</th>
                <th className="py-4 px-6">Shahar</th>
                <th className="py-4 px-6">Sana</th>
                <th className="py-4 px-6">Status</th>
                <th className="py-4 px-6 text-right">Harakatlar</th>
              </tr>
            </thead>

            <tbody className="divide-y divide-white/[0.06]">
              {isLoading ? (
                <tr>
                  <td colSpan={7} className="py-12 text-center text-gray-400">
                    <div className="w-8 h-8 rounded-full border-2 border-emerald-500 border-t-transparent animate-spin mx-auto mb-2" />
                    <span>Yuklanmoqda...</span>
                  </td>
                </tr>
              ) : leads.length === 0 ? (
                <tr>
                  <td colSpan={7} className="py-16 text-center text-gray-400">
                    <Users className="w-10 h-10 mx-auto mb-3 opacity-30" />
                    <p className="text-sm font-semibold text-white">Arizalar topilmadi</p>
                    <p className="text-xs text-gray-400 mt-1">Ushbu parametr bo'yicha ma'lumot yo'q</p>
                  </td>
                </tr>
              ) : (
                leads.map((lead) => (
                  <tr
                    key={lead.id}
                    className="hover:bg-white/[0.02] transition-colors group"
                  >
                    {/* Ism */}
                    <td className="py-4 px-6">
                      <div className="font-bold text-white text-sm">{lead.name}</div>
                      {lead.message && (
                        <div className="text-[11px] text-gray-400 truncate max-w-xs italic mt-0.5">
                          "{lead.message}"
                        </div>
                      )}
                    </td>

                    {/* Telefon with tel: link as requested */}
                    <td className="py-4 px-6">
                      <a
                        href={`tel:${lead.phone}`}
                        className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-emerald-500/10 hover:bg-emerald-500 text-emerald-400 hover:text-black font-mono font-bold transition-all"
                        title="Mobil qo'ng'iroq qilish"
                      >
                        <PhoneCall className="w-3.5 h-3.5" />
                        <span>{lead.phone}</span>
                      </a>
                    </td>

                    {/* Cafe */}
                    <td className="py-4 px-6 font-semibold text-gray-200">
                      {lead.businessName}
                    </td>

                    {/* Shahar */}
                    <td className="py-4 px-6 text-gray-300">
                      {lead.city}
                    </td>

                    {/* Sana */}
                    <td className="py-4 px-6 text-gray-400 font-mono text-[11px]">
                      {new Date(lead.createdAt).toLocaleDateString('uz-UZ', {
                        day: '2-digit',
                        month: '2-digit',
                        year: 'numeric',
                      })}
                    </td>

                    {/* Status */}
                    <td className="py-4 px-6">
                      <Badge status={lead.status} />
                    </td>

                    {/* Actions */}
                    <td className="py-4 px-6 text-right">
                      <div className="inline-flex items-center gap-1.5">
                        {/* Ko'rish */}
                        <button
                          onClick={() => setViewLead(lead)}
                          className="p-1.5 rounded-lg text-gray-400 hover:text-white hover:bg-white/10 transition-colors cursor-pointer"
                          title="Ko'rish"
                        >
                          <Eye className="w-4 h-4" />
                        </button>

                        {/* Statusni o'zgartirish */}
                        <button
                          onClick={() => {
                            setEditStatusLead(lead);
                            setNewStatus(lead.status as any);
                            setStatusNotes(lead.notes || '');
                          }}
                          className="p-1.5 rounded-lg text-emerald-400 hover:text-emerald-300 hover:bg-emerald-500/10 transition-colors cursor-pointer"
                          title="Statusni o'zgartirish"
                        >
                          <Edit className="w-4 h-4" />
                        </button>

                        {/* O'chirish */}
                        <button
                          onClick={() => handleDeleteLead(lead.id)}
                          className="p-1.5 rounded-lg text-gray-400 hover:text-red-400 hover:bg-red-500/10 transition-colors cursor-pointer"
                          title="O'chirish"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Modal 1: Lead Details View */}
      <Modal
        isOpen={!!viewLead}
        onClose={() => setViewLead(null)}
        title="Mijoz arizasi tafsilotlari"
      >
        {viewLead && (
          <div className="space-y-4">
            <div className="p-4 rounded-2xl bg-white/[0.03] border border-white/10 space-y-3">
              <div className="flex items-center justify-between">
                <div>
                  <h4 className="text-lg font-bold text-white">{viewLead.name}</h4>
                  <span className="text-xs text-gray-400">{viewLead.businessName}</span>
                </div>
                <Badge status={viewLead.status} />
              </div>

              <div className="grid grid-cols-2 gap-3 text-xs pt-2 border-t border-white/[0.06]">
                <div>
                  <span className="text-gray-400 block text-[11px]">Telefon raqami</span>
                  <a
                    href={`tel:${viewLead.phone}`}
                    className="text-emerald-400 font-bold font-mono text-sm hover:underline flex items-center gap-1 mt-0.5"
                  >
                    <PhoneCall className="w-3.5 h-3.5" />
                    {viewLead.phone}
                  </a>
                </div>

                <div>
                  <span className="text-gray-400 block text-[11px]">Shahar</span>
                  <span className="font-semibold text-white mt-0.5 block">{viewLead.city}</span>
                </div>

                <div>
                  <span className="text-gray-400 block text-[11px]">Ariza kelgan vaqt</span>
                  <span className="text-gray-300 font-mono mt-0.5 block">
                    {new Date(viewLead.createdAt).toLocaleString('uz-UZ')}
                  </span>
                </div>

                <div>
                  <span className="text-gray-400 block text-[11px]">Ariza ID</span>
                  <span className="text-gray-400 font-mono text-[10px] mt-0.5 block truncate">
                    {viewLead.id}
                  </span>
                </div>
              </div>

              {viewLead.message && (
                <div className="pt-2 border-t border-white/[0.06]">
                  <span className="text-gray-400 block text-[11px] mb-1">Mijoz qoldirgan izoh:</span>
                  <p className="text-xs text-gray-200 bg-black/30 p-3 rounded-xl border border-white/5">
                    {viewLead.message}
                  </p>
                </div>
              )}

              {viewLead.notes && (
                <div className="pt-2 border-t border-white/[0.06]">
                  <span className="text-amber-400 block text-[11px] mb-1 font-semibold">Director eslatmasi:</span>
                  <p className="text-xs text-gray-300 bg-amber-500/5 p-3 rounded-xl border border-amber-500/20">
                    {viewLead.notes}
                  </p>
                </div>
              )}
            </div>

            <div className="flex items-center gap-3 pt-2">
              <a
                href={`tel:${viewLead.phone}`}
                className="flex-1 py-3 rounded-xl bg-emerald-500 hover:bg-emerald-400 text-black text-xs font-bold text-center flex items-center justify-center gap-2 transition-colors"
              >
                <PhoneCall className="w-4 h-4" />
                Qo'ng'iroq qilish ({viewLead.phone})
              </a>

              <Button
                variant="secondary"
                size="md"
                onClick={() => {
                  setEditStatusLead(viewLead);
                  setNewStatus(viewLead.status as any);
                  setStatusNotes(viewLead.notes || '');
                  setViewLead(null);
                }}
              >
                Statusni o'zgartirish
              </Button>
            </div>
          </div>
        )}
      </Modal>

      {/* Modal 2: Change Status Modal */}
      <Modal
        isOpen={!!editStatusLead}
        onClose={() => setEditStatusLead(null)}
        title="Mijoz statusini o'zgartirish"
      >
        {editStatusLead && (
          <div className="space-y-4">
            <p className="text-xs text-gray-300">
              <span className="font-bold text-white">{editStatusLead.name}</span> ({editStatusLead.businessName}) uchun joriy holatni yangilang:
            </p>

            <div>
              <label className="block text-xs font-semibold text-gray-300 mb-2">Yangi status</label>
              <select
                value={newStatus}
                onChange={(e) => setNewStatus(e.target.value as any)}
                className="w-full glass-input px-3 py-2.5 rounded-xl text-sm bg-[#0A0D18]"
              >
                <option value="new">Yangi (new)</option>
                <option value="contacted">Bog'lanildi (contacted)</option>
                <option value="converted">Mijoz / Hamkor bo'ldi (converted)</option>
                <option value="rejected">Rad etildi (rejected)</option>
              </select>
            </div>

            <div>
              <label className="block text-xs font-semibold text-gray-300 mb-2">Qo'shimcha eslatma (Notes)</label>
              <textarea
                rows={3}
                placeholder="Mijoz bilan nima gaplashildi? Narx kelishildimi? Demo vaqti qachon?"
                value={statusNotes}
                onChange={(e) => setStatusNotes(e.target.value)}
                className="w-full glass-input p-3 rounded-xl text-xs resize-none"
              />
            </div>

            <div className="flex items-center justify-end gap-3 pt-3">
              <Button variant="ghost" size="sm" onClick={() => setEditStatusLead(null)}>
                Bekor qilish
              </Button>
              <Button
                variant="primary"
                size="sm"
                isLoading={isUpdating}
                onClick={handleUpdateStatus}
              >
                Saqlash
              </Button>
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
};
