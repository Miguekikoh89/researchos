import { Controller, Post, Get, Param, Request, UseInterceptors, UploadedFile, BadRequestException, HttpCode, HttpStatus } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { DatasetsService } from './datasets.service';

@Controller('projects/:projectId/datasets')
export class DatasetsController {
  constructor(private readonly datasetsService: DatasetsService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @UseInterceptors(FileInterceptor('file'))
  async upload(@Param('projectId') projectId: string, @UploadedFile() file: Express.Multer.File, @Request() req: any) {
    if (!file) throw new BadRequestException('No se recibió ningún archivo');
    return this.datasetsService.uploadDataset(file, projectId, req.user.id);
  }

  @Get()
  async findAll(@Param('projectId') projectId: string, @Request() req: any) {
    return this.datasetsService.findByProject(projectId, req.user.id);
  }

  @Get(':datasetId')
  async findOne(@Param('datasetId') datasetId: string, @Request() req: any) {
    return this.datasetsService.findOne(datasetId, req.user.id);
  }

  @Get(':datasetId/preview')
  async preview(@Param('datasetId') datasetId: string, @Request() req: any) {
    return this.datasetsService.getPreview(datasetId, req.user.id);
  }
}
