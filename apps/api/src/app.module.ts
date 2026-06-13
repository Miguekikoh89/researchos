import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';

import { AuthModule }     from './auth/auth.module';
import { ProjectsModule } from './projects/projects.module';
import { DatasetsModule } from './datasets/datasets.module';
import { AdminModule } from './admin/admin.module';
import { AnalysisModule } from './analysis/analysis.module';
import { JwtAuthGuard }   from './auth/jwt.guard';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    AuthModule,
    ProjectsModule,
    DatasetsModule,
    AnalysisModule,
    AdminModule,
  ],
  providers: [
    // Apply JWT guard globally; use @Public() decorator to opt out
    { provide: APP_GUARD, useClass: JwtAuthGuard },
  ],
})
export class AppModule {}
