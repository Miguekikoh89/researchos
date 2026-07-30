import { Module } from '@nestjs/common';
import { SavedConfigsController } from './saved-configs.controller';
import { SavedConfigsService } from './saved-configs.service';
import { PrismaService } from '../common/prisma.service';

@Module({
  controllers: [SavedConfigsController],
  providers: [SavedConfigsService, PrismaService],
})
export class SavedConfigsModule {}
