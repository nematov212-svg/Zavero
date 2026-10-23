export interface PublicStats {
  cafes: number;
  employees: number;
  orders: number;
  customers: number;
}

export interface Cafe {
  id: string;
  name: string;
  ownerName: string;
  phone: string;
  city: string;
  address: string;
  status: 'ACTIVE' | 'INACTIVE';
  apiKey: string;
  activeTables: number;
  logoUrl?: string;
  createdAt: string;
  updatedAt?: string;
  _count?: {
    employees: number;
    orders: number;
    customers: number;
  };
}

export interface Lead {
  id: string;
  name: string;
  phone: string;
  businessName: string;
  city: string;
  message?: string | null;
  status: 'new' | 'contacted' | 'converted' | 'rejected';
  notes?: string | null;
  createdAt: string;
  updatedAt?: string;
}

export interface Employee {
  id: string;
  cafeId: string;
  name: string;
  role: string;
  phone: string;
  ordersCount: number;
  closedOrdersCount: number;
  salesAmount: number;
  attendanceStatus: string;
  rating: number;
  createdAt: string;
  cafe?: {
    name: string;
    city: string;
  };
}

export interface NotificationItem {
  id: string;
  title: string;
  message: string;
  type: string;
  isRead: boolean;
  leadId?: string;
  lead?: Lead;
  createdAt: string;
}

export interface User {
  id: string;
  email: string;
  name: string;
  role: string;
}

export interface AuthState {
  token: string | null;
  user: User | null;
  isAuthenticated: boolean;
}

export interface DirectorDashboardData {
  overview: {
    activeCafes: number;
    totalCafes: number;
    employees: number;
    orders: number;
    customers: number;
    totalLeads: number;
    newLeads: number;
    totalRevenue: number;
  };
  recentLeads: Lead[];
  recentCafes: Cafe[];
}
