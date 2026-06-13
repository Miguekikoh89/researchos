import { Injectable, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';

@Injectable()
export class AdminService {
  constructor(private prisma: PrismaService) {}

  private async checkAdmin(userId: string) {
    const user = await this.prisma.user.findFirst({ where: { id: userId } });
    if (!user || user.role !== 'ADMIN') throw new ForbiddenException('Admin access required');
    return user;
  }

  async getStats(userId: string) {
    await this.checkAdmin(userId);
    const [totalUsers, totalJobs, completedJobs, failedJobs, todayUsers, todayJobs] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.analysisJob.count(),
      this.prisma.analysisJob.count({ where: { status: 'COMPLETED' } }),
      this.prisma.analysisJob.count({ where: { status: 'FAILED' } }),
      this.prisma.user.count({ where: { createdAt: { gte: new Date(new Date().setHours(0,0,0,0)) } } }),
      this.prisma.analysisJob.count({ where: { createdAt: { gte: new Date(new Date().setHours(0,0,0,0)) } } }),
    ]);

    // Analysis by category
    const jobs = await this.prisma.analysisJob.findMany({ select: { config: true, createdAt: true, status: true } });
    const byCategory: Record<string, number> = {};
    jobs.forEach((j: any) => {
      const cat = (j.config as any)?.analysis_category || 'unknown';
      byCategory[cat] = (byCategory[cat] || 0) + 1;
    });

    // Last 7 days activity
    const days: { date: string; jobs: number; users: number }[] = [];
    for (let i = 6; i >= 0; i--) {
      const d = new Date(); d.setDate(d.getDate() - i); d.setHours(0,0,0,0);
      const end = new Date(d); end.setHours(23,59,59,999);
      const [j, u] = await Promise.all([
        this.prisma.analysisJob.count({ where: { createdAt: { gte: d, lte: end } } }),
        this.prisma.user.count({ where: { createdAt: { gte: d, lte: end } } }),
      ]);
      days.push({ date: d.toISOString().split('T')[0], jobs: j, users: u });
    }

    return { totalUsers, totalJobs, completedJobs, failedJobs, todayUsers, todayJobs, byCategory, days };
  }

  async getUsers(userId: string) {
    await this.checkAdmin(userId);
    const users = await this.prisma.user.findMany({
      orderBy: { createdAt: 'desc' },
      select: { id: true, email: true, name: true, role: true, isActive: true, createdAt: true, _count: { select: { projects: true } } },
    });
    const projects = await this.prisma.project.findMany({ 
      select: { userId: true, _count: { select: { jobs: true } } } 
    });
    const jobMap: Record<string, number> = {};
    projects.forEach((p: any) => { jobMap[p.userId] = (jobMap[p.userId]||0) + p._count.jobs; });
    return users.map((u: any) => ({
      id: u.id, email: u.email, name: u.name, role: u.role,
      createdAt: u.createdAt, projects: u._count.projects,
      analyses: jobMap[u.id] || 0,
    }));
  }

  async getActivity(userId: string) {
    await this.checkAdmin(userId);
    const jobs = await this.prisma.analysisJob.findMany({
      orderBy: { createdAt: 'desc' },
      take: 50,
      include: { project: { include: { user: { select: { email: true, name: true } } } } },
    });
    return jobs.map((j: any) => ({
      id: j.id, status: j.status,
      category: (j.config as any)?.analysis_category || '-',
      user: j.project?.user?.email || '-',
      userName: j.project?.user?.name || '-',
      createdAt: j.createdAt,
    }));
  }

  async updateRole(adminId: string, userId: string, role: string) {
    await this.checkAdmin(adminId);
    return this.prisma.user.update({ where: { id: userId }, data: { role: role as any } });
  }

  async updateStatus(adminId: string, userId: string, active: boolean) {
    await this.checkAdmin(adminId);
    return this.prisma.user.update({ where: { id: userId }, data: { role: active ? 'STUDENT' : 'STUDENT' } });
  }

  async deleteUser(adminId: string, userId: string) {
    await this.checkAdmin(adminId);
    await this.prisma.user.delete({ where: { id: userId } });
    return { success: true };
  }

  async toggleUserActive(adminId: string, userId: string, active: boolean) {
    await this.checkAdmin(adminId);
    return this.prisma.user.update({ where: { id: userId }, data: { isActive: active } });
  }

  async getUserAnalyses(adminId: string, userId: string) {
    await this.checkAdmin(adminId);
    const jobs = await this.prisma.analysisJob.findMany({
      where: { project: { userId } },
      orderBy: { createdAt: 'desc' },
      include: { project: { select: { name: true } } },
    });
    return jobs.map((j: any) => ({
      id: j.id, status: j.status,
      category: (j.config as any)?.analysis_category || '-',
      project: j.project?.name || '-',
      createdAt: j.createdAt,
    }));
  }

  async getMetrics(adminId: string) {
    await this.checkAdmin(adminId);
    const now = new Date();
    const months: any[] = [];
    for (let i = 5; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const end = new Date(now.getFullYear(), now.getMonth() - i + 1, 0, 23, 59, 59);
      const [jobs, users] = await Promise.all([
        this.prisma.analysisJob.count({ where: { createdAt: { gte: d, lte: end } } }),
        this.prisma.user.count({ where: { createdAt: { gte: d, lte: end } } }),
      ]);
      months.push({ month: d.toISOString().slice(0, 7), jobs, users });
    }
    const thirtyDaysAgo = new Date(); thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    const activeUsers = await this.prisma.project.findMany({
      where: { createdAt: { gte: thirtyDaysAgo } },
      select: { userId: true }, distinct: ['userId' as any],
    });
    return { months, activeUsers: activeUsers.length };
  }

  async getLogs(adminId: string) {
    await this.checkAdmin(adminId);
    return this.prisma.auditLog.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: { user: { select: { email: true, name: true } } },
    });
  }
}
