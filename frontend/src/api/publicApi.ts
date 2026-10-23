import { request } from './client';
import { PublicStats, Cafe, Lead } from '../types';

export const publicApi = {
  getStatistics: () => {
    return request<PublicStats>('/api/public/statistics');
  },

  getCafes: () => {
    return request<{ success: boolean; count: number; data: Cafe[] }>('/api/public/cafes');
  },

  createLead: (data: {
    name: string;
    phone: string;
    businessName: string;
    city: string;
    message?: string;
  }) => {
    return request<{ success: boolean; message: string; data: Lead }>('/api/leads', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  },
};
