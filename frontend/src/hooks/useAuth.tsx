import React, { createContext, useContext, useState, useEffect } from 'react';
import { User, AuthState } from '../types';
import { authApi } from '../api/authApi';

interface AuthContextType extends AuthState {
  login: (token: string, user: User) => void;
  logout: () => void;
  isLoading: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [token, setToken] = useState<string | null>(() => localStorage.getItem('zavero_token'));
  const [user, setUser] = useState<User | null>(() => {
    const saved = localStorage.getItem('zavero_user');
    return saved ? JSON.parse(saved) : null;
  });
  const [isLoading, setIsLoading] = useState<boolean>(true);

  useEffect(() => {
    const verifyUser = async () => {
      const savedToken = localStorage.getItem('zavero_token');
      if (savedToken) {
        try {
          const res = await authApi.getMe();
          if (res.success && res.data) {
            setUser(res.data);
            localStorage.setItem('zavero_user', JSON.stringify(res.data));
          }
        } catch (err) {
          console.warn('Session expired or invalid, logging out:', err);
          logout();
        }
      }
      setIsLoading(false);
    };

    verifyUser();
  }, []);

  const login = (newToken: string, newUser: User) => {
    setToken(newToken);
    setUser(newUser);
    localStorage.setItem('zavero_token', newToken);
    localStorage.setItem('zavero_user', JSON.stringify(newUser));
  };

  const logout = () => {
    setToken(null);
    setUser(null);
    localStorage.removeItem('zavero_token');
    localStorage.removeItem('zavero_user');
  };

  return (
    <AuthContext.Provider
      value={{
        token,
        user,
        isAuthenticated: !!token && !!user,
        login,
        logout,
        isLoading,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
