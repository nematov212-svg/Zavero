import { request } from './client';
import { User } from '../types';

export const authApi = {
  login: (credentials: { email: string; password: string }) => {
    return request<{
      success: boolean;
      message: string;
      data: {
        token: string;
        user: User;
      };
    }>('/api/auth/login', {
      method: 'POST',
      body: JSON.stringify(credentials),
    });
  },

  getMe: () => {
    return request<{ success: boolean; data: User }>('/api/auth/me');
  },

  changePassword: (data: { currentPassword: string; newPassword: string }) => {
    return request<{ success: boolean; message: string }>('/api/auth/change-password', {
      method: 'PATCH',
      body: JSON.stringify(data),
    });
  },
};
