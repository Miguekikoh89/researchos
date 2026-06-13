import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
export interface CreateProjectDto { name: string; description?: string; }
export interface UpdateProjectDto { name?: string; description?: string; }
@Injectable()
export class ProjectsService {
  constructor(private prisma: PrismaService) {}
  async findAll(userId: string) {
    return this.prisma.project.findMany({ where: { userId }, include: { _count: { select: { jobs: true, datasets: true } } }, orderBy: { updatedAt: 'desc' } });
  }
  async findOne(id: string, userId: string) {
    const project = await this.prisma.project.findUnique({ where: { id }, include: { datasets: { orderBy: { createdAt: 'desc' }, take: 5 }, jobs: { orderBy: { createdAt: 'desc' }, take: 10, include: { result: true } } } });
    if (!project) throw new NotFoundException('Proyecto no encontrado');
    if (project.userId !== userId) throw new ForbiddenException('Sin acceso');
    return project;
  }
  async create(data: CreateProjectDto, userId: string) { return this.prisma.project.create({ data: { ...data, userId } }); }
  async update(id: string, data: UpdateProjectDto, userId: string) { await this.findOne(id, userId); return this.prisma.project.update({ where: { id }, data }); }
  async remove(id: string, userId: string) { await this.findOne(id, userId); return this.prisma.project.delete({ where: { id } }); }
  async getDashboardStats(userId: string) {
    const [projects, recentJobs, totalProjects, totalAnalyses, completedAnalyses] = await Promise.all([
      this.prisma.project.findMany({ where: { userId }, include: { _count: { select: { jobs: true } } }, orderBy: { updatedAt: 'desc' }, take: 5 }),
      this.prisma.analysisJob.findMany({ where: { project: { userId } }, orderBy: { createdAt: 'desc' }, take: 10, include: { project: { select: { name: true } }, result: { select: { method: true } } } }),
      this.prisma.project.count({ where: { userId } }),
      this.prisma.analysisJob.count({ where: { project: { userId } } }),
      this.prisma.analysisJob.count({ where: { project: { userId }, status: 'COMPLETED' } }),
    ]);
    return { projects, recentJobs, totalProjects, totalAnalyses, completedAnalyses };
  }
}
