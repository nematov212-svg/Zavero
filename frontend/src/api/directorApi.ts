import { request } from './client';
import { Lead, Cafe, Employee, NotificationItem, DirectorDashboardData } from '../types';

export const directorApi = {
  getDashboard: () => {
    return request<{ success: boolean; data: DirectorDashboardData }>('/api/director/dashboard');
  },

  // Leads
  getLeads: (params?: { status?: string; search?: string; page?: number; limit?: number }) => {
    return request<{
      success: boolean;
      leads: Lead[];
      pagination: { total: number; page: number; limit: number; totalPages: number };
    }>('/api/director/leads', { params });
  },

  getLeadById: (id: string) => {
    return request<{ success: boolean; data: Lead }>(`/api/director/leads/${id}`);
  },

  updateLeadStatus: (id: string, data: { status: string; notes?: string }) => {
    return request<{ success: boolean; message: string; data: Lead }>(`/api/director/leads/${id}/status`, {
      method: 'PATCH',
      body: JSON.stringify(data),
    });
  },

  deleteLead: (id: string) => {
    return request<{ success: boolean; message: string }>(`/api/director/leads/${id}`, {
      method: 'DELETE',
    });
  },

  // Cafes
  getCafes: (search?: string) => {
    return request<{ success: boolean; data: Cafe[] }>('/api/director/cafes', {
      params: { search },
    });
  },

  getCafeById: (id: string) => {
    return request<{ success: boolean; data: Cafe }>(`/api/director/cafes/${id}`);
  },

  createCafe: (data: {
    name: string;
    ownerName: string;
    phone: string;
    city: string;
    address: string;
    activeTables?: number;
    status?: 'ACTIVE' | 'INACTIVE';
  }) => {
    return request<{ success: boolean; message: string; data: Cafe }>('/api/director/cafes', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  },

  updateCafe: (id: string, data: Partial<Cafe>) => {
    return request<{ success: boolean; message: string; data: Cafe }>(`/api/director/cafes/${id}`, {
      method: 'PATCH',
      body: JSON.stringify(data),
    });
  },

  deleteCafe: (id: string) => {
    return request<{ success: boolean; message: string }>(`/api/director/cafes/${id}`, {
      method: 'DELETE',
    });
  },

  regenerateApiKey: (id: string) => {
    return request<{ success: boolean; message: string; apiKey: string }>(`/api/director/cafes/${id}/regenerate-key`, {
      method: 'POST',
    });
  },

  // Employees
  getEmployees: () => {
    return request<{ success: boolean; data: Employee[] }>('/api/director/employees');
  },

  // Notifications
  getNotifications: () => {
    return request<{ success: boolean; data: NotificationItem[] }>('/api/director/notifications');
  },

  markNotificationRead: (id: string) => {
    return request<{ success: boolean; message: string }>(`/api/director/notifications/${id}/read`, {
      method: 'PATCH',
    });
  },

  markAllNotificationsRead: () => {
    return request<{ success: boolean; message: string }>('/api/director/notifications/read-all', {
      method: 'POST',
    });
  },
};
