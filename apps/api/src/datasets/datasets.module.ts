import { Module } from '@nestjs/common';
import { DatasetsService } from './datasets.service';
import { DatasetsController } from './datasets.controller';
import { PrismaService } from '../common/prisma.service';

@Module({
  providers: [DatasetsService, PrismaService],
  controllers: [DatasetsController],
  exports: [DatasetsService],
})
export class DatasetsModule {}
