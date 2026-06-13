import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding database...');

  const hash = await bcrypt.hash('password123', 12);

  const student = await prisma.user.upsert({
    where: { email: 'estudiante@demo.com' },
    update: {},
    create: {
      name: 'Ana García',
      email: 'estudiante@demo.com',
      password: hash,
      role: 'STUDENT',
    },
  });

  const advisor = await prisma.user.upsert({
    where: { email: 'asesor@demo.com' },
    update: {},
    create: {
      name: 'Dr. Carlos López',
      email: 'asesor@demo.com',
      password: hash,
      role: 'ADVISOR',
    },
  });

  const project = await prisma.project.upsert({
    where: { id: 'demo-project-1' },
    update: {},
    create: {
      id: 'demo-project-1',
      name: 'Correlación estrés-rendimiento académico',
      description: 'Estudio correlacional en estudiantes universitarios',
      userId: student.id,
    },
  });

  console.log('✅ Seed complete');
  console.log(`   👩‍🎓 Estudiante: estudiante@demo.com / password123`);
  console.log(`   👨‍🏫 Asesor:     asesor@demo.com / password123`);
}

main()
  .catch(e => { console.error(e); process.exit(1); })
  .finally(() => prisma.$disconnect());
