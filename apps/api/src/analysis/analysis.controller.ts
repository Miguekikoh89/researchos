// ============================================================================
// ResearchOS Stats Engine — analysis.controller.ts
// ============================================================================

import {
  Controller, Post, Get, Param, Body, Req,
  UseGuards, Res, StreamableFile, HttpCode,
} from '@nestjs/common';
import { AnalysisService, AnalysisConfig } from './analysis.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Response } from 'express';
import * as fs from 'fs';
import * as path from 'path';

@Controller('projects/:projectId/analysis')
@UseGuards(JwtAuthGuard)
export class AnalysisController {
  constructor(private readonly analysisService: AnalysisService) {}

  // POST /projects/:projectId/analysis
  @Post()
  @HttpCode(202)
  async createAnalysis(
    @Param('projectId') projectId: string,
    @Body() body: { datasetId: string; config: AnalysisConfig },
  ) {
    const job = await this.analysisService.createJob(
      projectId,
      body.datasetId,
      body.config,
    );
    return {
      jobId: job.id,
      status: job.status,
      message: 'Análisis iniciado. Consulta el estado en GET /analysis/:jobId',
    };
  }

  // GET /projects/:projectId/analysis
  @Get()
  async listAnalysis(@Param('projectId') projectId: string) {
    return this.analysisService.listJobsByProject(projectId);
  }

  // GET /projects/:projectId/analysis/:jobId
  @Get(':jobId')
  async getJob(@Param('jobId') jobId: string) {
    return this.analysisService.getJob(jobId);
  }

  // GET /projects/:projectId/analysis/:jobId/result
  @Get(':jobId/result')
  async getResult(@Param('jobId') jobId: string) {
    return this.analysisService.getResult(jobId);
  }

  // GET /projects/:projectId/analysis/:jobId/download/word
  @Get(':jobId/download/word')
  async downloadWord(
    @Param('jobId') jobId: string,
    @Res({ passthrough: true }) res: Response,
  ) {
    const wordPath = await this.analysisService.getWordPath(jobId);
    const filename = path.basename(wordPath);
    res.set({
      'Content-Type': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'Content-Disposition': `attachment; filename="${filename}"`,
    });
    return new StreamableFile(fs.createReadStream(wordPath));
  }
}
