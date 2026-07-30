import { Injectable } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';

@Injectable()
export class SavedConfigsService {
  constructor(private prisma: PrismaService) {}

  findAll(userId: string) {
    return this.prisma.savedConfig.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      select: { id: true, name: true, method: true, config: true, createdAt: true }
    });
  }

  create(userId: string, name: string, method: string, config: any) {
    return this.prisma.savedConfig.create({
      data: { userId, name, method, config }
    });
  }

  remove(userId: string, id: string) {
    return this.prisma.savedConfig.deleteMany({
      where: { id, userId }
    });
  }
}
