import { Injectable, BadRequestException, NotFoundException, ForbiddenException } from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';
import { PrismaService } from '../common/prisma.service';

const ALLOWED_EXTS = ['.xlsx', '.xls', '.csv'];
const MAX_SIZE = 50 * 1024 * 1024;

@Injectable()
export class DatasetsService {
  constructor(private prisma: PrismaService) {}

  async uploadDataset(file: Express.Multer.File, projectId: string, userId: string) {
    const ext = path.extname(file.originalname).toLowerCase();
    if (!ALLOWED_EXTS.includes(ext)) throw new BadRequestException('Solo .xlsx, .xls o .csv');
    if (file.size > MAX_SIZE) throw new BadRequestException('Archivo supera 50 MB');
    const project = await this.prisma.project.findFirst({ where: { id: projectId, userId } });
    if (!project) throw new ForbiddenException('Proyecto no encontrado o sin acceso');

    const uploadDir = path.join(process.env.UPLOAD_DIR || '/tmp/uploads', userId);
    fs.mkdirSync(uploadDir, { recursive: true });
    const storedName = `${crypto.randomBytes(16).toString('hex')}${ext}`;
    const storedPath = path.join(uploadDir, storedName);
    fs.writeFileSync(storedPath, file.buffer);

    let columns: any[] = [];
    try {
      if (ext === '.csv') {
        const firstLine = file.buffer.toString('utf8').split('\n')[0];
        columns = firstLine.split(',').map((h) => ({ name: h.trim(), type: 'numeric' }));
      } else {
        // Read xlsx headers using built-in approach
        const XLSX = require('xlsx');
        const wb = XLSX.read(file.buffer, { type: 'buffer' });
        const ws = wb.Sheets[wb.SheetNames[0]];
        const data: any[][] = XLSX.utils.sheet_to_json(ws, { header: 1 });
        if (data.length > 0 && Array.isArray(data[0])) {
          columns = (data[0] as any[]).map((h: any) => ({ name: String(h ?? '').trim(), type: 'numeric' })).filter(c => c.name);
        }
      }
    } catch (e) {
      console.error('Error reading columns:', e);
    }

    const dataset = await this.prisma.dataset.create({
      data: {
        projectId,
        originalName: file.originalname.replace(/[^a-zA-Z0-9._\- ]/g, '_'),
        storedPath,
        mimeType: file.mimetype,
        sizeBytes: file.size,
        columns: columns.length ? columns : undefined,
        columnCount: columns.length,
      },
    });

    return { ...dataset, columns };
  }

  async findByProject(projectId: string, userId: string) {
    const project = await this.prisma.project.findFirst({ where: { id: projectId, userId } });
    if (!project) throw new ForbiddenException('Sin acceso');
    return this.prisma.dataset.findMany({ where: { projectId }, orderBy: { createdAt: 'desc' } });
  }

  async findOne(datasetId: string, userId: string) {
    const dataset = await this.prisma.dataset.findUnique({ where: { id: datasetId }, include: { project: true } });
    if (!dataset) throw new NotFoundException('Dataset no encontrado');
    if (dataset.project.userId !== userId) throw new ForbiddenException('Sin acceso');
    return dataset;
  }

  async getPreview(datasetId: string, userId: string) {
    const dataset = await this.findOne(datasetId, userId);
    return { id: dataset.id, originalName: dataset.originalName, columns: dataset.columns || [], rowCount: dataset.rowCount, sizeBytes: dataset.sizeBytes };
  }
}
