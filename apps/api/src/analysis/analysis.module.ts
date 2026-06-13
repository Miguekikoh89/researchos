import { Module } from '@nestjs/common';
import { AnalysisService } from './analysis.service';
import { AnalysisController } from './analysis.controller';
import { PrismaService } from '../common/prisma.service';

@Module({
  providers: [AnalysisService, PrismaService],
  controllers: [AnalysisController],
  exports: [AnalysisService],
})
export class AnalysisModule {}
