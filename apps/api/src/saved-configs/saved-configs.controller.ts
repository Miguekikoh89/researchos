import { Controller, Get, Post, Delete, Body, Param, Request, UseGuards } from '@nestjs/common';
import { SavedConfigsService } from './saved-configs.service';
import { JwtAuthGuard } from '../auth/jwt.guard';

@Controller('saved-configs')
@UseGuards(JwtAuthGuard)
export class SavedConfigsController {
  constructor(private readonly service: SavedConfigsService) {}

  @Get()
  findAll(@Request() req: any) {
    return this.service.findAll(req.user.userId);
  }

  @Post()
  create(@Request() req: any, @Body() body: { name: string; method: string; config: any }) {
    return this.service.create(req.user.userId, body.name, body.method, body.config);
  }

  @Delete(':id')
  remove(@Request() req: any, @Param('id') id: string) {
    return this.service.remove(req.user.userId, id);
  }
}
