const fs = require('node:fs');
const path = require('node:path');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, deleteDoc, serverTimestamp } =
  require('firebase/firestore');

// Estas pruebas verifican las reglas de Firestore en el emulador local.
describe('TaskFlow Firestore rules', function () {
  let environment;

  before(async function () {
    environment = await initializeTestEnvironment({
      projectId: 'demo-taskflow',
      firestore: {
        rules: fs.readFileSync(
          path.join(__dirname, '..', '..', 'firestore.rules'),
          'utf8',
        ),
      },
    });
  });

  beforeEach(async function () {
    await environment.clearFirestore();
  });

  after(async function () {
    await environment.cleanup();
  });

  function taskDocument(db, userId, taskId = 'task-1') {
    return doc(db, 'users', userId, 'tasks', taskId);
  }

  // Coincide con los campos y tipos que TaskModel escribe en Firestore.
  function validTask() {
    return {
      title: 'Revisar proyecto',
      description: 'Verificar reglas',
      category: 'Trabajo',
      priority: 'Alta',
      dueDate: null,
      isCompleted: false,
      recurrence: 'none',
      recurrenceDay: null,
      subtasks: [],
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    };
  }

  // Ejecuta estas pruebas solo contra el emulador local.
  // El dueño debe poder gestionar documentos válidos en su propia ruta.
  it('allows an owner to create, read, update and delete a valid task', async function () {
    const db = environment.authenticatedContext('alice').firestore();
    const reference = taskDocument(db, 'alice');

    await assertSucceeds(setDoc(reference, validTask()));
    await assertSucceeds(getDoc(reference));
    await assertSucceeds(
      updateDoc(reference, {
        title: 'Tarea actualizada',
        updatedAt: serverTimestamp(),
      }),
    );
    await assertSucceeds(deleteDoc(reference));
  });

  // Ninguna sesión puede leer o escribir la colección privada de otra cuenta.
  it('denies access from a different user and from unauthenticated clients', async function () {
    const aliceDb = environment.authenticatedContext('alice').firestore();
    await assertSucceeds(setDoc(taskDocument(aliceDb, 'alice'), validTask()));

    const bobDb = environment.authenticatedContext('bob').firestore();
    await assertFails(getDoc(taskDocument(bobDb, 'alice')));
    await assertFails(
      setDoc(taskDocument(bobDb, 'alice', 'task-2'), validTask()),
    );
    await assertFails(
      getDoc(
        taskDocument(environment.unauthenticatedContext().firestore(), 'alice'),
      ),
    );
  });

  // Las reglas rechazan campos no permitidos y preservan la fecha de creación.
  it('rejects invalid task fields and changing the creation timestamp', async function () {
    const db = environment.authenticatedContext('alice').firestore();
    const reference = taskDocument(db, 'alice');
    const invalidTask = {...validTask(), priority: 'Urgente'};

    await assertFails(setDoc(reference, invalidTask));
    await assertSucceeds(setDoc(reference, validTask()));
    await assertFails(
      updateDoc(reference, {
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('rejects invalid recurrence and oversized checklists', async function () {
    const db = environment.authenticatedContext('alice').firestore();
    const reference = taskDocument(db, 'alice');

    await assertFails(
      setDoc(reference, {...validTask(), recurrence: 'yearly'}),
    );
    await assertFails(
      setDoc(reference, {
        ...validTask(),
        subtasks: Array.from({length: 21}, (_, index) => ({
          title: `Subtarea ${index}`,
          isCompleted: false,
        })),
      }),
    );
  });

  it('continues to accept older tasks without recurrence or subtasks', async function () {
    const db = environment.authenticatedContext('alice').firestore();
    const reference = taskDocument(db, 'alice');
    const {recurrence, recurrenceDay, subtasks, ...legacyTask} = validTask();

    await assertSucceeds(setDoc(reference, legacyTask));
    await assertSucceeds(
      updateDoc(reference, {
        isCompleted: true,
        updatedAt: serverTimestamp(),
      }),
    );
  });
});
